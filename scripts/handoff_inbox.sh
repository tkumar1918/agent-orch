#!/usr/bin/env bash
# Agent-run. Pull the coordination repo and show open handoffs addressed to this side,
# plus open proposal PRs (in-flight, not yet merged). One command for /handoff-check.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
eval "$(python3 "$DIR/_config.py")" || exit 1
: "${CFG_PROJECT:?set 'project:' in ~/.handoff/config.yml}"

[ -d "$CFG_COORDINATION_CLONE/.git" ] || { echo "clone not found: $CFG_COORDINATION_CLONE (git clone $CFG_COORDINATION_REPO)" >&2; exit 1; }
cd "$CFG_COORDINATION_CLONE"
git fetch -q origin 2>/dev/null || true
git checkout -q main 2>/dev/null || true
git pull -q 2>/dev/null || true

echo "## [$CFG_PROJECT] Open handoffs to: $CFG_ROLE (merged)"
python3 "$DIR/_inbox.py" "$CFG_COORDINATION_CLONE/projects/$CFG_PROJECT/handoffs" "$CFG_ROLE"

echo
echo "## [$CFG_PROJECT] Open proposal PRs (in-flight, not yet merged)"
if command -v gh >/dev/null 2>&1; then
  gh pr list --repo "$CFG_COORDINATION_REPO" --state open \
     --json number,title,headRefName \
     --jq ".[] | select(.headRefName|startswith(\"proposal/$CFG_PROJECT/\")) | \"  #\(.number) \(.title) [\(.headRefName)]\"" 2>/dev/null \
     || echo "  (gh not authenticated — run: gh auth login)"
else
  echo "  (gh not installed)"
fi
