#!/usr/bin/env bash
# Agent-run. Sync local code to the shared contract; report drift vs the last sync.
# FE regenerates the typed client; BE prints provider verify.
# One command for /contract-sync.
#
#   contract_sync.sh [--ref <branch|sha>]   (default ref: main = released contract)
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
eval "$(python3 "$DIR/_config.py")" || exit 1
: "${CFG_PROJECT:?set 'project:' in ~/.handoff/config.yml}"

REF="main"
if [ "${1:-}" = "--ref" ]; then REF="${2:?--ref needs a value}"; fi

cd "$CFG_COORDINATION_CLONE"
git fetch -q origin 2>/dev/null || true
git checkout -q "$REF" 2>/dev/null || git checkout -q -b "$REF" "origin/$REF" 2>/dev/null || true
git pull -q 2>/dev/null || true

REL="projects/$CFG_PROJECT/$CFG_CONTRACT_PATH"
CONTRACT="$CFG_COORDINATION_CLONE/$REL"
NEWHASH="$(git hash-object "$REL")"
echo "synced $REL @ $REF (contract hash $NEWHASH)"

# Drift report vs last sync (compares contract content via oasdiff). Per-project state.
LAST="$HOME/.handoff/last_sync-$CFG_PROJECT"
if [ -f "$LAST" ]; then
  PREVHASH="$(cut -d' ' -f1 "$LAST")"
  if [ "$PREVHASH" != "$NEWHASH" ] && git cat-file -e "$PREVHASH" 2>/dev/null; then
    git cat-file -p "$PREVHASH" > /tmp/_prev_contract
    echo "## Contract moved since last sync ($PREVHASH -> $NEWHASH):"
    "$DIR/contract_diff.sh" /tmp/_prev_contract "$CONTRACT" || true
  fi
fi

case "$CFG_ROLE" in
  frontend)
    if command -v openapi-typescript >/dev/null 2>&1; then
      openapi-typescript "$CONTRACT" -o "$CFG_CLIENT_TYPES_OUT"
      echo "regenerated client types -> $CFG_CLIENT_TYPES_OUT"
    else
      echo "[skip] openapi-typescript not installed; run: openapi-typescript $CONTRACT -o $CFG_CLIENT_TYPES_OUT"
    fi
    ;;
  backend)
    echo "verify provider: schemathesis run --base-url <local-url> $CONTRACT   (or: dredd)"
    ;;
esac

mkdir -p "$HOME/.handoff"
echo "$NEWHASH $REF" > "$LAST"
echo "recorded sync state -> $LAST"
