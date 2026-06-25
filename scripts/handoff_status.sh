#!/usr/bin/env bash
# Agent-run. Transition a handoff's status by committing straight to main — no PR.
# A status change (acknowledged/in-progress/completed/...) is just a state marker, not a
# contract negotiation, so it does not need review. The human gate is the proposal PR on the
# CONTRACT; status updates flow freely. Used by /handoff-check (acknowledge) and as work moves.
#
#   handoff_status.sh <id> <acknowledged|in-progress|completed|blocked|rejected>
#   (DRY_RUN=1 sets + validates the field but does not commit/push)
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
eval "$(python3 "$DIR/_config.py")" || exit 1
: "${CFG_PROJECT:?set project in this project .handoff/config.yml}"

ID="${1:?usage: handoff_status.sh <id> <status>}"
STATUS="${2:?status required}"
cd "$CFG_COORDINATION_CLONE"
P="projects/$CFG_PROJECT"
git fetch -q origin 2>/dev/null || true
git checkout -q -f main          # status always commits to main; -f discards any stray edits
git pull -q --ff-only 2>/dev/null || true

python3 "$DIR/_set_field.py" "$P/handoffs/$ID.md" status "$STATUS"
python3 "$DIR/validate_handoff.py" "$P/handoffs/$ID.md"

if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "[dry-run] would set $ID status -> $STATUS and commit to main"
  git checkout -q -- "$P/handoffs/$ID.md" 2>/dev/null || true   # revert the working-tree edit
  exit 0
fi
git add "$P/handoffs/$ID.md"
git commit -q -m "[$CFG_PROJECT] $ID: status -> $STATUS"
git push -q origin main
echo "status committed to main: $ID -> $STATUS"
