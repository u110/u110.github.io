#!/usr/bin/env bash
#
# 次期 Ruby ビルド検証用の matrix を算出する。
#
# 使い方:
#   .github/scripts/resolve-ruby-matrix.sh
#       .ruby-version より新しい安定マイナー + "head" を JSON 配列で出力
#
#   MANUAL_INPUT='["4.1","head"]' .github/scripts/resolve-ruby-matrix.sh
#       MANUAL_INPUT が空でなければそのまま出力 (workflow_dispatch の上書き想定)
#
# 出力:
#   標準出力に JSON 配列 (例: ["4.0","head"])
#   GITHUB_OUTPUT が設定されていれば versions=<json> も追記
#
# 依存:
#   gh (認証済み) / jq は不要 (gh の --jq を利用)
set -euo pipefail

if [ -n "${MANUAL_INPUT:-}" ]; then
  versions="$MANUAL_INPUT"
else
  current=$(cat .ruby-version)
  cmajor=$(echo "$current" | cut -d. -f1)
  cminor=$(echo "$current" | cut -d. -f2)
  versions=$(gh api 'repos/ruby/ruby/releases?per_page=100' --jq "
    [.[]
      | select(.prerelease == false and .draft == false)
      | .name
      | capture(\"^(?<major>[0-9]+)\\\\.(?<minor>[0-9]+)\\\\.(?<patch>[0-9]+)\$\")
      | {major: (.major|tonumber), minor: (.minor|tonumber)}]
    | unique
    | map(select(.major > $cmajor or (.major == $cmajor and .minor > $cminor)))
    | map(\"\(.major).\(.minor)\")
    | . + [\"head\"]")
fi

echo "$versions"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "versions=$versions" >> "$GITHUB_OUTPUT"
fi
