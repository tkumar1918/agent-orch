#!/usr/bin/env bash
# Create a coordination repo from coordination-repo-template/ and (optionally) add the two
# devs as collaborators. Run ONCE per coordination repo. Needs: gh (authenticated) + git.
#
#   ./bootstrap.sh <owner/repo> [options]
#     --private | --public      visibility (default: private)
#     --project <name>          rename the seed project folder (default: example-app)
#     --collab <github-user>    add as a push collaborator on the new repo (repeatable)
#     --no-sample               drop the example handoff (keep an empty handoffs/ skeleton)
#
# Example — a coordination repo for one frontend/backend pair, both devs added:
#   ./bootstrap.sh acme/web-app-coordination --private \
#       --project web-app --collab alice-fe --collab bob-be
set -euo pipefail

REPO=""; VIS="--private"; PROJECT=""; NO_SAMPLE=0; COLLABS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --private) VIS="--private" ;;
    --public)  VIS="--public" ;;
    --project) PROJECT="${2:?--project needs a name}"; shift ;;
    --collab)  COLLABS+=("${2:?--collab needs a user}"); shift ;;
    --no-sample) NO_SAMPLE=1 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *)  REPO="$1" ;;
  esac
  shift
done
[ -n "$REPO" ] || { echo "usage: bootstrap.sh <owner/repo> [--private|--public] [--project name] [--collab user]..." >&2; exit 2; }
command -v gh  >/dev/null || { echo "gh not found (https://cli.github.com)"  >&2; exit 2; }
command -v git >/dev/null || { echo "git not found" >&2; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Seed the repo: template + vendored tools/.
cp -r "$HERE/coordination-repo-template/." "$WORK/"
mkdir -p "$WORK/tools"
cp "$HERE"/scripts/*.py "$HERE"/scripts/*.sh "$WORK/tools/"

PROJ="${PROJECT:-example-app}"
if [ "$PROJ" != "example-app" ]; then
  mv "$WORK/projects/example-app" "$WORK/projects/$PROJ"
  sed -i "s/example-app/$PROJ/g" "$WORK/CODEOWNERS"
fi
if [ "$NO_SAMPLE" = 1 ]; then
  rm -f "$WORK/projects/$PROJ/handoffs/"[!_]*.md
  : > "$WORK/projects/$PROJ/handoffs/.gitkeep"
fi

cd "$WORK"
git init -q -b main
git add -A
git commit -q -m "Bootstrap coordination repo from template (project: $PROJ)"
gh repo create "$REPO" $VIS --source=. --remote=origin --push

# Add collaborators (push access) so each repo-scoped dev can read/write the neutral repo.
for u in ${COLLABS[@]+"${COLLABS[@]}"}; do
  gh api -X PUT "repos/$REPO/collaborators/$u" -f permission=push >/dev/null \
    && echo "invited collaborator: $u (push)"
done

cat <<EOF

Created: https://github.com/$REPO   (project: $PROJ)
Next:
  - Protect 'main': Settings > Branches > require review from Code Owners.
  - Edit CODEOWNERS with your real team/user handles.
  - Replace projects/$PROJ/contracts/openapi.yaml with your real spec.
  - On each laptop: set coordination_repo, project: $PROJ in ~/.handoff/config.yml, then clone.
EOF
