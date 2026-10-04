#!/usr/bin/env bash
# Regenerate plugins/*/skills from manaflow-ai/cmux and apply the Claude Code
# adaptations in scripts/claudeify.py. Never edit plugins/*/skills by hand:
# change claudeify.py and re-run this script.
#
#   scripts/sync-upstream.sh            # sync to the ref in UPSTREAM
#   scripts/sync-upstream.sh main       # sync to a new ref and record it
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

ref="${1:-$(sed -n 's/^ref=//p' UPSTREAM)}"
[[ -n "$ref" ]] || { echo "sync-upstream: no ref given and none in UPSTREAM" >&2; exit 1; }

sha="$(curl -fsSL "https://api.github.com/repos/manaflow-ai/cmux/commits/$ref" | python3 -c 'import json,sys; print(json.load(sys.stdin)["sha"])')"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Fetching manaflow-ai/cmux@$sha"
curl -fsSL "https://codeload.github.com/manaflow-ai/cmux/tar.gz/$sha" |
  tar -xz -C "$tmp" --strip-components=1 "cmux-$sha/skills" "cmux-$sha/LICENSE" "cmux-$sha/THIRD_PARTY_LICENSES.md"

python3 scripts/claudeify.py "$tmp/skills" "$repo_root"
cp "$tmp/LICENSE" LICENSE
cp "$tmp/THIRD_PARTY_LICENSES.md" THIRD_PARTY_LICENSES.md

printf 'repo=manaflow-ai/cmux\nref=%s\nsha=%s\n' "$ref" "$sha" > UPSTREAM
echo "Synced to $sha. Review with: git diff --stat"
