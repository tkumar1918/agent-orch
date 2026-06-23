#!/usr/bin/env bash
# Agent-run. Pull the coordination repo and show open handoffs addressed to this side,
# plus open proposal PRs (in-flight, not yet merged). One command for /handoff-check.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
eval "$(python3 "$DIR/_config.py")" || exit 1

[ -d "$CFG_COORDINATION_CLONE/.git" ] || { echo "clone not found: $CFG_COORDINATION_CLONE (git clone $CFG_COORDINATION_REPO)" >&2; exit 1; }
cd "$CFG_COORDINATION_CLONE"
git fetch -q origin 2>/dev/null || true
git checkout -q main 2>/dev/null || true
git pull -q 2>/dev/null || true

echo "## Open handoffs to: $CFG_ROLE (merged)"
python3 "$DIR/_inbox.py" "$CFG_COORDINATION_CLONE/handoffs" "$CFG_ROLE"

echo
echo "## Open proposal PRs (in-flight, not yet merged)"
if command -v gh >/dev/null 2>&1; then
  gh pr list --repo "$CFG_COORDINATION_REPO" --state open \
     --json number,title,headRefName \
     --jq '.[] | "  #\(.number) \(.title) [\(.headRefName)]"' 2>/dev/null \
     || echo "  (gh not authenticated — run: gh auth login)"
else
  echo "  (gh not installed)"
fi
