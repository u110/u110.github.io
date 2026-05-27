#!/usr/bin/env bash
#
# ruby-next.yml の build-next が失敗したとき、追跡 issue にコメントを追加する。
#
# - タイトル完全一致 (open) で追跡 issue を探す
# - 見つかったらコメント追加
# - 見つからない (= close 済 or 未起票) なら静かに終了
#
# 使い方:
#   RUBY_VERSION='4.0' \
#   RUN_URL='https://github.com/...' \
#   .github/scripts/notify-ruby-next-failure.sh
#
# 環境変数 (必須):
#   RUBY_VERSION  失敗した Ruby バージョン (例: "4.0", "head")
#   RUN_URL       該当 workflow run の URL
#
# 環境変数 (任意):
#   TRACKING_TITLE  追跡 issue のタイトル (デフォルトは下記)
#   GH_TOKEN        gh CLI 認証用 (CI では ${{ github.token }} を渡す)
#
# 依存:
#   gh (認証済み)
set -euo pipefail

: "${RUBY_VERSION:?RUBY_VERSION is required}"
: "${RUN_URL:?RUN_URL is required}"

TRACKING_TITLE="${TRACKING_TITLE:-Ruby 4.0 / head での Jekyll ビルドが github-pages 依存により失敗する}"

issue_number=$(gh issue list \
  --state open \
  --search "in:title \"$TRACKING_TITLE\"" \
  --json number,title \
  --jq "[.[] | select(.title == \"$TRACKING_TITLE\")] | .[0].number // empty")

if [ -z "$issue_number" ]; then
  echo "No open tracking issue found (title: $TRACKING_TITLE). Skipping comment."
  exit 0
fi

echo "Adding comment to issue #$issue_number"
gh issue comment "$issue_number" --body "$(cat <<EOF
build-next (\`$RUBY_VERSION\`) が失敗しました。

- Run: $RUN_URL
- 日時 (UTC): $(date -u +'%Y-%m-%d %H:%M:%S')
EOF
)"
