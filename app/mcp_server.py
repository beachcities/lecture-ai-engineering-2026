"""第6回: 用語集と各回の要点を MCP サーバーとして公開する。

使い方:
    uv run python -m app.mcp_agent --list-tools     # このサーバーが公開するツールを一覧する（APIキー不要）
    uv run python -m app.mcp_server --http          # Streamable HTTP で起動する（http://127.0.0.1:8000/mcp）

引数なしで実行すると stdio（標準入出力）で待ち受ける。これは MCP クライアント（app.mcp_agent など）が
サブプロセスとして起動する使い方なので、手で実行すると入力待ちのまま止まって見える。

第3回では tools.py の関数を agent.py に直接登録した。MCP サーバーにすると、同じ関数を
エージェントのプログラム（app/mcp_agent.py）からも、MCP に対応したほかのソフトウェアからも、
共通の手順で使えるようになる。

宿題（実装）: 第3回の make_quiz を公開し、存在しない回を指定されたときの知らせ方を 3 通りで比べる。
    --quiz-error return      メッセージを return で返す（既定）
    --quiz-error valueerror  同じメッセージで ValueError を投げる
    --quiz-error toolerror   同じメッセージで MCP SDK の ToolError を投げる
SDK（mcp 2.3.0）は、ToolError 以外の例外を「想定外の失敗」として扱い、クライアントには
"Error executing tool <name>" だけを返す（メッセージは渡らない）。ToolError なら、
メッセージを is_error=True の結果として返す。どちらがモデルにどう届くかを --trace で確かめる。
"""

import argparse
import sys

from mcp.server.mcpserver import MCPServer
from mcp.server.mcpserver.exceptions import ToolError

from app import tools

QUIZ_ERROR_MODES = ("return", "valueerror", "toolerror")


def _quiz_error_mode(argv: list[str]) -> str:
    """起動時の引数から --quiz-error の値を読む（ツールの登録より前に決める必要があるため）。"""
    for i, arg in enumerate(argv):
        if arg == "--quiz-error" and i + 1 < len(argv):
            return argv[i + 1]
        if arg.startswith("--quiz-error="):
            return arg.split("=", 1)[1]
    return "return"


QUIZ_ERROR_MODE = _quiz_error_mode(sys.argv[1:])

# サーバーの名前と説明。クライアントに表示される（設定ファイル側のキー "glossary" とは別物）
server = MCPServer(
    "aie2026-glossary",
    instructions="AIE2026（AIエンジニアリング実践講座）の用語集と各回の要点を提供する。",
)

# 第3回と同じ関数を、そのまま MCP のツールとして公開する。docstring と型ヒントが説明文になる
server.tool()(tools.search_glossary)

# TODO(宿題・基礎): get_lecture_summary も公開しよう


# 宿題（実装）: 第3回の make_quiz を公開する。説明文は第3回と同じにして、変えるのは範囲外の知らせ方だけ
def make_quiz(lecture: int) -> str:
    """指定した回（1始まりの整数）の用語から1つを選び、確認問題と答えを返す。

    「第2回の確認問題を出して」のように、復習用の問題を求められたときに使う。
    lecture には回の番号を入れる（例: 2）。
    """
    available = sorted({e["lecture"] for e in tools.load_glossary()})
    if lecture not in available:
        # どの引数が、どんな値で、どう直せばよいかを書く（講義 Part 3「エラーには直し方を書く」）
        message = (
            f"lecture={lecture} の回は用語集にありません。"
            f"lecture には用語がある回の番号（{', '.join(map(str, available))}）のどれかを指定してください。"
        )
        if QUIZ_ERROR_MODE == "toolerror":
            raise ToolError(message)
        if QUIZ_ERROR_MODE == "valueerror":
            raise ValueError(message)
        return message
    return tools.make_quiz(lecture)


server.tool()(make_quiz)


def main() -> None:
    parser = argparse.ArgumentParser(description="用語集 MCP サーバー")
    parser.add_argument("--http", action="store_true", help="Streamable HTTP で起動する（既定は stdio）")
    parser.add_argument(
        "--quiz-error",
        choices=QUIZ_ERROR_MODES,
        default="return",
        help="make_quiz で存在しない回を指定されたときの知らせ方（宿題・実装の比較用）",
    )
    args = parser.parse_args()
    if args.http:
        print("MCP サーバーを http://127.0.0.1:8000/mcp で起動します（Ctrl+C で停止）")
        server.run(transport="streamable-http")
    else:
        # stdio では標準出力がプロトコルの通信路になるので、print してはいけない
        server.run()


if __name__ == "__main__":
    main()
