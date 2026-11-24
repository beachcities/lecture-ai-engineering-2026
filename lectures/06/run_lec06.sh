#!/usr/bin/env bash
# 第6回 演習（STEP 1〜4）と宿題・実装のコマンドを順に実行し、表示を lectures/06/logs/ に保存して push する。
#
# 使い方（Codespaces のターミナルで、リポジトリのどこからでも）:
#     bash lectures/06/run_lec06.sh
#
# - app/mcp_servers.json を STEP ごとの設定（lectures/06/configs/）に差し替えながら実行し、最後に元へ戻す
# - 「レート制限」「混み合っています」が出たら 60 秒待って 1 回だけやり直す
# - 所要は 6〜10 分ほど（各コマンドの間に 15 秒待つため）

set -u
cd "$(git rev-parse --show-toplevel)"

LOG=lectures/06/logs
CONF=lectures/06/configs
CONFIG=app/mcp_servers.json
mkdir -p "$LOG"
cp "$CONFIG" /tmp/mcp_servers.json.orig
trap 'cp /tmp/mcp_servers.json.orig "$CONFIG"' EXIT

use_config() {
  cp "$CONF/$1.json" "$CONFIG"
}

run() {
  # run <ログ名> <コマンド...>
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
  tail -n 3 "$file" | sed 's/^/   /'
  sleep 15
}

echo "== 準備: uv sync --frozen"
uv sync --frozen

# 演習 STEP 1・2：自分で作った用語集サーバーだけ
use_config step1_2
run step1_agent_list-tools uv run python -m app.agent --list-tools
run step1_mcp_agent_list-tools uv run python -m app.mcp_agent --list-tools
run step2_trace uv run python -m app.mcp_agent --trace "AIE2026の講座の宿題にある「3レベル」とは何ですか？"

# 演習 STEP 3：公開されている fetch サーバーを足す
use_config step3
run step3_list-tools uv run python -m app.mcp_agent --list-tools
run step3_trace uv run python -m app.mcp_agent --trace "https://modelcontextprotocol.io/ の冒頭を日本語で3行に要約して"

# 演習 STEP 4：外部で動く AWS Knowledge サーバーに URL で接続する
use_config step4
run step4_list-tools uv run python -m app.mcp_agent --list-tools
run step4_trace uv run python -m app.mcp_agent --trace "AWSのドキュメントを検索して、Amazon S3 のバージョニングを2行で説明して"

# 宿題・実装：make_quiz を公開し、存在しない回の知らせ方を 3 通りで比べる（用語集サーバーだけ）
use_config quiz_return
run hw_list-tools uv run python -m app.mcp_agent --list-tools
run hw_return_ok uv run python -m app.mcp_agent --trace "第2回のクイズを作って"
run hw_return_99 uv run python -m app.mcp_agent --trace "第99回のクイズを作って"
use_config quiz_valueerror
run hw_valueerror_99 uv run python -m app.mcp_agent --trace "第99回のクイズを作って"
use_config quiz_toolerror
run hw_toolerror_99 uv run python -m app.mcp_agent --trace "第99回のクイズを作って"

# 設定を元に戻してからテスト
cp /tmp/mcp_servers.json.orig "$CONFIG"
run pytest uv run pytest -q

echo "== ログを commit して push"
git add "$LOG"
git commit -q -m "第6回 演習・宿題（実装）の実行ログ"
git push -u origin lec06
echo "== 完了。チャットに「終わりました」と送ってください"
