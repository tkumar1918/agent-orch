#!/usr/bin/env bash
# Mint a unique handoff id and scaffold a manifest from the template.
#
#   new_handoff.sh <from: frontend|backend> [handoffs_dir]
#
# Prints the path of the new manifest. The id is YYYY-MM-DD-<from>-NNN where NNN is
# the next free sequence for that date+producer, guaranteeing uniqueness/idempotency.
set -euo pipefail

FROM="${1:-}"
DIR="${2:-handoffs}"
case "$FROM" in
  frontend|fe) FROM=frontend; ABBR=fe ;;
  backend|be)  FROM=backend;  ABBR=be ;;
  *) echo "usage: new_handoff.sh <frontend|backend> [handoffs_dir]" >&2; exit 2 ;;
esac

DATE="$(date +%F)"
n=1
while :; do
  ID="$(printf '%s-%s-%03d' "$DATE" "$ABBR" "$n")"
  OUT="$DIR/$ID.md"
  [ -e "$OUT" ] || break
  n=$((n + 1))
done

TEMPLATE="$DIR/_template.md"
[ -f "$TEMPLATE" ] || { echo "template not found: $TEMPLATE" >&2; exit 2; }

# Seed handoff_id and from; the agent/human fills the rest.
sed -e "s|^handoff_id: .*|handoff_id: $ID|" \
    -e "s|^from: .*|from: $FROM|" \
    -e "s|^contract_branch: .*|contract_branch: proposal/$ABBR-$(printf '%03d' "$n")|" \
    "$TEMPLATE" > "$OUT"

echo "$OUT"
