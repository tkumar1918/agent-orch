#!/usr/bin/env bash
# Mint a unique handoff id and scaffold a manifest from the template.
#
#   new_handoff.sh <from: frontend|backend> [handoffs_dir]
#
# Prints the path of the new manifest. The id is YYYY-MM-DD-<side>-NNN-<rand>: NNN is a
# best-effort daily sequence (human ordering only) and <rand> is a short random hex suffix
# that makes concurrent same-side mints collision-proof (two clones may pick the same NNN,
# but the suffix differs, so the full id, branch, and filename never collide).
set -euo pipefail

FROM="${1:-}"
DIR="${2:-handoffs}"
case "$FROM" in
  frontend|fe) FROM=frontend; ABBR=fe ;;
  backend|be)  FROM=backend;  ABBR=be ;;
  *) echo "usage: new_handoff.sh <frontend|backend> [handoffs_dir]" >&2; exit 2 ;;
esac

DATE="$(date +%F)"

# Best-effort daily sequence for this date+side (human-friendly ordering only).
shopt -s nullglob
n=1
for _f in "$DIR/$DATE-$ABBR-"*.md; do n=$((n + 1)); done

# Append a random hex suffix so two simultaneous same-side mints can never collide.
# Re-roll on the astronomically unlikely event the path already exists.
while :; do
  RAND="$(head -c2 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n')"
  [ -n "$RAND" ] || RAND="$(printf '%04x' $(( (RANDOM << 8 ^ RANDOM) & 0xffff )))"
  ID="$(printf '%s-%s-%03d-%s' "$DATE" "$ABBR" "$n" "$RAND")"
  OUT="$DIR/$ID.md"
  [ -e "$OUT" ] || break
done

# The template is shared at the coordination-repo root — walk up from the handoffs dir.
find_up() {
  local d; d="$(cd "$1" && pwd)"
  while :; do
    [ -f "$d/$2" ] && { echo "$d/$2"; return 0; }
    [ "$d" = "/" ] && return 1
    d="$(dirname "$d")"
  done
}
TEMPLATE="$(find_up "$DIR" _template.md || true)"
[ -n "$TEMPLATE" ] && [ -f "$TEMPLATE" ] || { echo "_template.md not found above $DIR" >&2; exit 2; }

# Project = the dir that contains handoffs/  (…/projects/<project>/handoffs).
PROJECT="$(basename "$(dirname "$DIR")")"

# Seed handoff_id, from, and the project-qualified branch; the agent/human fills the rest.
sed -e "s|^handoff_id: .*|handoff_id: $ID|" \
    -e "s|^from: .*|from: $FROM|" \
    -e "s|^contract_branch: .*|contract_branch: proposal/$PROJECT/$ID|" \
    "$TEMPLATE" > "$OUT"

echo "$OUT"
