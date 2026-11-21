#!/usr/bin/env bash
# 第5回 演習・宿題（基礎）の実行をまとめたスクリプト。
# 演習：同じ質問を 全文投入／ベクトル検索／Tree／Graph で1回ずつ。
# 宿題（基礎）：app/config.py の RAG_TOP_K を 5→2 に変え、前後を同じ質問で各3回。
# 出力はすべて lectures/05/runs/ に保存する。
set -u
cd "$(git rev-parse --show-toplevel)"
OUT=lectures/05/runs
mkdir -p "$OUT"
WAIT=${WAIT:-20}   # レート制限よけの待ち秒数

Q1='第2回の説明では、LoRAは何を固定し何を学習しますか？ QLoRAは何を加えますか？'
Q2='第3回の例では、コンパクションとセッションをまたぐメモリはどう違いますか。日々のメモはすべて長期メモリに入りますか'

run() {  # run <ログ名> <引数...>
  local name=$1; shift
  echo "=== $name ($(date '+%F %T'))"
  { echo "# $(date '+%F %T') RAG_TOP_K=$(grep -oP '^RAG_TOP_K = \K\d+' app/config.py)"
    echo "# cmd: $*"
    uv run python "$@" 2>&1; } > "$OUT/$name.log"
  tail -3 "$OUT/$name.log"
  sleep "$WAIT"
}

grep -q '^RAG_TOP_K = 5$' app/config.py || { echo "RAG_TOP_K が 5 ではありません。止めます"; exit 1; }

# --- 演習（RAG_TOP_K=5）
run ex_retrieval_k5   -m app.retrieval "LoRA QLoRA 違い"
run ex_full_q1        -m app.agent --full-context --trace "$Q1"
run ex_vector_q1      -m app.agent --trace "$Q1"
run ex_tree_q1        -m app.agent --tree --trace "$Q1"
run ex_graph_q1       -m app.agent --graph --trace "$Q1"

# --- 宿題・変更前（RAG_TOP_K=5）
run hw_retrieval_q2_k5 -m app.retrieval "コンパクション セッション メモリ 長期メモリ"
for i in 1 2 3; do
  run hw_k5_q1_r$i -m app.agent --trace "$Q1"
  run hw_k5_q2_r$i -m app.agent --trace "$Q2"
done

# --- 宿題・変更（RAG_TOP_K 5→2）
sed -i 's/^RAG_TOP_K = 5$/RAG_TOP_K = 2/' app/config.py
grep -n '^RAG_TOP_K' app/config.py

# --- 宿題・変更後（RAG_TOP_K=2）
run hw_retrieval_q1_k2 -m app.retrieval "LoRA QLoRA 違い"
run hw_retrieval_q2_k2 -m app.retrieval "コンパクション セッション メモリ 長期メモリ"
for i in 1 2 3; do
  run hw_k2_q1_r$i -m app.agent --trace "$Q1"
  run hw_k2_q2_r$i -m app.agent --trace "$Q2"
done

# --- まとめ
{ for f in "$OUT"/*.log; do
    echo "## $(basename "$f")"
    grep -E '^\[(model|time|usage|cost|tool call)\]|エラー|レート制限' "$f"
  done; } > "$OUT/summary.txt"
echo "完了。lectures/05/runs/summary.txt を確認してください"
