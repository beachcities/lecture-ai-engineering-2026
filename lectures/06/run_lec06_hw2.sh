#!/usr/bin/env bash
# 第6回 宿題・実装の追加実行：「第5回のクイズを作って」を 3 通りの知らせ方で 2 回ずつ実行する。
#
# 1 回目の比較（第99回）では、return と toolerror でモデルがツールを呼ばずに答えたため、同じ条件で比べられなかった。
# 用語集には第5回の用語がない（用語がある回は 1, 2, 3, 4, 6）ので、実在しそうな回で範囲外を起こす。
#
# 使い方（Codespaces のターミナルで）:
#     bash lectures/06/run_lec06_hw2.sh

set -u
cd "$(git rev-parse --show-toplevel)"

LOG=lectures/06/logs
CONF=lectures/06/configs
CONFIG=app/mcp_servers.json
mkdir -p "$LOG"
cp "$CONFIG" /tmp/mcp_servers.json.orig
trap 'cp /tmp/mcp_servers.json.orig "$CONFIG"' EXIT

run() {
  local name=$1
  shift
  local file="$LOG/$name.txt"
  echo "== $name"
  {
    echo "\$ $*"
    echo "[date] $(date '+%Y-%m-%d %H:%M:%S %Z')"
    "$@" 2>&1
  } >"$file"
  if grep -q "レート制限\|混み合って" "$file"; then
    echo "   レート制限などのため 60 秒待ってやり直します"
    sleep 60
    {
      echo "\$ $*  （やり直し）"
      echo "[date] $(date '+%Y-%m-%d %H:%M:%S %Z')"
      "$@" 2>&1
    } >"$file"
  fi
  grep "^\[tool" "$file" | cut -c1-120 | sed 's/^/   /'
  sleep 20
}

for mode in return valueerror toolerror; do
  cp "$CONF/quiz_$mode.json" "$CONFIG"
  for n in 1 2; do
    run "hw2_${mode}_5_try$n" uv run python -m app.mcp_agent --trace "第5回のクイズを作って"
  done
done

cp /tmp/mcp_servers.json.orig "$CONFIG"
echo "== ログを commit して push"
git add "$LOG"
git commit -q -m "第6回 宿題（実装）：第5回で範囲外の知らせ方を比較した実行ログ"
git push
echo "== 完了。チャットに「終わりました」と送ってください"
