#!/usr/bin/env bash
# Agent-run. After the agent has drafted handoffs/<id>.md and edited the contract in the
# coordination clone, this validates, pins the contract hash, branches, commits, pushes,
# and opens the PR. One command for the tail of /handoff-create.
#
#   handoff_submit.sh <handoffs/<id>.md>        (DRY_RUN=1 skips push + PR)
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
eval "$(python3 "$DIR/_config.py")" || exit 1

MANIFEST="${1:?usage: handoff_submit.sh <handoffs/<id>.md>}"
cd "$CFG_COORDINATION_CLONE"
ID="$(basename "$MANIFEST" .md)"
BRANCH="proposal/$ID"

git checkout -q -b "$BRANCH" 2>/dev/null || git checkout -q "$BRANCH"

# Pin contract_version to the contract's content hash (stable; no self-reference problem).
CVER="$(git hash-object "$CFG_CONTRACT_PATH")"
python3 "$DIR/_set_field.py" "handoffs/$ID.md" contract_version "$CVER"
python3 "$DIR/_set_field.py" "handoffs/$ID.md" contract_branch "$BRANCH"

python3 "$DIR/validate_handoff.py" "handoffs/$ID.md"

git add "$CFG_CONTRACT_PATH" "handoffs/$ID.md"
git commit -q -m "$ID: handoff + contract change"

if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "[dry-run] validated + committed $BRANCH (contract_version=$CVER); would push + open PR"
  exit 0
fi
git push -q -u origin "$BRANCH"
gh pr create --repo "$CFG_COORDINATION_REPO" --base main --head "$BRANCH" --title "$ID" --fill
echo "opened PR for $BRANCH — recipient: run /handoff-check"
