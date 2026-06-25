#!/usr/bin/env bash
# Agent-run. Transition a handoff's status and open a small PR recording it.
# Used by /handoff-check (acknowledge) and as work progresses.
#
#   handoff_status.sh <id> <acknowledged|in-progress|completed|blocked|rejected>
#   (DRY_RUN=1 skips push + PR)
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
eval "$(python3 "$DIR/_config.py")" || exit 1
: "${CFG_PROJECT:?set 'project:' in ~/.handoff/config.yml}"

ID="${1:?usage: handoff_status.sh <id> <status>}"
STATUS="${2:?status required}"
cd "$CFG_COORDINATION_CLONE"
P="projects/$CFG_PROJECT"
git fetch -q origin 2>/dev/null || true
git checkout -q main 2>/dev/null || true
git pull -q 2>/dev/null || true

BRANCH="status/$CFG_PROJECT/$ID-$STATUS"
git checkout -q -b "$BRANCH" 2>/dev/null || git checkout -q "$BRANCH"
python3 "$DIR/_set_field.py" "$P/handoffs/$ID.md" status "$STATUS"
python3 "$DIR/validate_handoff.py" "$P/handoffs/$ID.md"
git add "$P/handoffs/$ID.md"
git commit -q -m "[$CFG_PROJECT] $ID: status -> $STATUS"

if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "[dry-run] set $ID status -> $STATUS on $BRANCH; would push + open PR"
  exit 0
fi
git push -q -u origin "$BRANCH"
gh pr create --repo "$CFG_COORDINATION_REPO" --base main --head "$BRANCH" \
  --title "$ID: $STATUS" --fill
echo "status PR opened: $ID -> $STATUS"
