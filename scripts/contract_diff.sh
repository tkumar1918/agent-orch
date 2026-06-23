#!/usr/bin/env bash
# Wrap oasdiff: classify breaking changes + emit a human-readable changelog.
# Used by /handoff-create (to fill the manifest) and /contract-sync (drift report).
#
#   contract_diff.sh <old.yaml> <new.yaml>
#
# Prints the changelog to stdout and a "BREAKING: yes|no" line to stderr.
# Exit code: 0 = no breaking changes, 1 = breaking changes, 2 = usage/tooling error.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: contract_diff.sh <old-contract> <new-contract>" >&2
  exit 2
fi
OLD="$1"; NEW="$2"

if ! command -v oasdiff >/dev/null 2>&1; then
  echo "oasdiff not found. Install: https://github.com/oasdiff/oasdiff" >&2
  exit 2
fi

echo "=== changelog ($OLD -> $NEW) ==="
oasdiff changelog "$OLD" "$NEW" || true

# `oasdiff breaking --fail-on ERR` exits non-zero when breaking changes exist.
if oasdiff breaking "$OLD" "$NEW" --fail-on ERR >/dev/null 2>&1; then
  echo "BREAKING: no" >&2
  exit 0
else
  echo "BREAKING: yes" >&2
  echo "=== breaking detail ===" >&2
  oasdiff breaking "$OLD" "$NEW" || true
  exit 1
fi
