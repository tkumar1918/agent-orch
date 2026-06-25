#!/usr/bin/env bash
# Enroll THIS laptop into a coordination repo: clone it, install the skills + tools,
# and write ~/.handoff/config.yml. Run ONCE per laptop (re-run with --force to refresh).
# Needs: git + gh (authenticated). Does not need admin on the repo — just collaborator access.
#
#   ./enroll.sh --repo <owner/repo> --role <frontend|backend> --identity <name> --project <name> [options]
#     --clone <dir>          where to clone the coordination repo (default: ~/work/<repo-name>)
#     --contract-path <p>    contract path within the project (default: contracts/openapi.yaml)
#     --force                overwrite an existing ~/.handoff/config.yml
#
# Example — frontend dev Alice enrolling into the shared repo for project web-app:
#   ./enroll.sh --repo acme/agent-handoff --role frontend --identity alice --project web-app
set -euo pipefail

REPO=""; ROLE=""; IDENTITY=""; PROJECT=""; CLONE=""; CONTRACT_PATH="contracts/openapi.yaml"; FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)          REPO="${2:?--repo needs <owner/repo>}"; shift ;;
    --role)          ROLE="${2:?--role needs frontend|backend}"; shift ;;
    --identity)      IDENTITY="${2:?--identity needs a name}"; shift ;;
    --project)       PROJECT="${2:?--project needs a name}"; shift ;;
    --clone)         CLONE="${2:?--clone needs a dir}"; shift ;;
    --contract-path) CONTRACT_PATH="${2:?--contract-path needs a path}"; shift ;;
    --force)         FORCE=1 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *)  echo "unexpected argument: $1" >&2; exit 2 ;;
  esac
  shift
done
[ -n "$REPO" ]     || { echo "usage: enroll.sh --repo <owner/repo> --role <frontend|backend> --identity <name> --project <name>" >&2; exit 2; }
[ -n "$ROLE" ]     || { echo "--role is required (frontend|backend)" >&2; exit 2; }
[ -n "$IDENTITY" ] || { echo "--identity is required" >&2; exit 2; }
[ -n "$PROJECT" ]  || { echo "--project is required" >&2; exit 2; }
case "$ROLE" in frontend|backend) ;; *) echo "--role must be frontend or backend" >&2; exit 2 ;; esac
command -v git >/dev/null || { echo "git not found" >&2; exit 2; }
command -v gh  >/dev/null || { echo "gh not found (https://cli.github.com)" >&2; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo /nonexistent)"
# Run straight from the GitHub link: if the scaffold isn't next to us, fetch it with gh.
if [ ! -d "$HERE/claude-skills" ]; then
  SCAFFOLD_REPO="${SCAFFOLD_REPO:-tkumar1918/agent-orch}"
  echo "no local scaffold — fetching $SCAFFOLD_REPO via gh ..."
  HERE="$(mktemp -d)"
  trap 'rm -rf "$HERE"' EXIT
  gh repo clone "$SCAFFOLD_REPO" "$HERE" -- --depth 1 -q
fi
REPO_NAME="${REPO##*/}"
CLONE="${CLONE:-$HOME/work/$REPO_NAME}"
CLONE="${CLONE/#\~/$HOME}"
SKILLS_DIR="$HOME/.claude/skills"
TOOLS_DIR="$HOME/.handoff/tools"
CONFIG="$HOME/.handoff/config.yml"

# 1. Clone the coordination repo (skip if it's already there).
if [ -d "$CLONE/.git" ]; then
  echo "clone exists: $CLONE (leaving it as-is)"
else
  mkdir -p "$(dirname "$CLONE")"
  gh repo clone "$REPO" "$CLONE"
  echo "cloned $REPO -> $CLONE"
fi

# 2. Install the Claude Code skills.
mkdir -p "$SKILLS_DIR"
cp -r "$HERE"/claude-skills/* "$SKILLS_DIR/"
echo "installed skills -> $SKILLS_DIR"

# 3. Vendor the wrapper scripts the skills shell out to.
mkdir -p "$TOOLS_DIR"
cp "$HERE"/scripts/*.py "$HERE"/scripts/*.sh "$TOOLS_DIR/"
echo "installed tools  -> $TOOLS_DIR"

# 4. Write ~/.handoff/config.yml (don't clobber an existing one without --force).
if [ -f "$CONFIG" ] && [ "$FORCE" != 1 ]; then
  echo "config exists: $CONFIG (re-run with --force to overwrite) — skipping"
else
  mkdir -p "$(dirname "$CONFIG")"
  cat > "$CONFIG" <<EOF
# Per-laptop handoff config, written by enroll.sh. Edit freely.
role: $ROLE
identity: $IDENTITY

coordination_repo: git@github.com:$REPO.git
coordination_clone: $CLONE
project: $PROJECT

contract_path: $CONTRACT_PATH
contract_format: openapi

# Frontend-only: where generated client types and the mock live.
client_types_out: src/api/types.ts
mock_port: 4010
EOF
  echo "wrote config     -> $CONFIG"
fi

# 5. Dependency check (warn-only; the skills need these at runtime).
echo
miss=()
for c in python3 oasdiff; do command -v "$c" >/dev/null || miss+=("$c"); done
python3 -c 'import yaml, jsonschema' 2>/dev/null || miss+=("python: pyyaml+jsonschema (pip install pyyaml jsonschema)")
if [ "$ROLE" = frontend ]; then
  command -v openapi-typescript >/dev/null || miss+=("openapi-typescript (npm i -g openapi-typescript)")
  command -v prism >/dev/null || miss+=("prism (npm i -g @stoplight/prism-cli)")
else
  command -v schemathesis >/dev/null || miss+=("schemathesis (pip install schemathesis)")
fi
if [ ${#miss[@]} -gt 0 ]; then
  echo "heads up — install these for the skills to run:"
  for m in "${miss[@]}"; do echo "  - $m"; done
else
  echo "all runtime deps present."
fi

cat <<EOF

Enrolled as $ROLE ($IDENTITY) on project '$PROJECT'.
  clone:  $CLONE
  config: $CONFIG
Next: open Claude Code and run /handoff-check (consumer) or /handoff-create (producer).
EOF
