---
name: handoff-create
description: >
  Draft and open a cross-repo handoff to the other team (frontend<->backend). Use when the
  local change affects the shared API contract, or when you need the other side to act. The
  AGENT executes every step (inspect diff, edit contract, classify breaking changes, draft
  the manifest, validate, branch, commit, push, open the PR). The human only states intent
  and approves/merges the PR.
---

# /handoff-create

**Automation contract:** you (the agent) run all commands below. Do NOT ask the human to run
git/oasdiff/gh by hand. The only human steps are (1) confirming the intent/summary and
(2) approving the PR on GitHub. Tools live in `~/.handoff/tools/`.

**Config — do this ONCE, first, and never read a config file yourself.** Run
`eval "$(~/.handoff/tools/_config.py)"`. It resolves the project-local `.handoff/config.yml`
(walking up from your cwd) or falls back to the global `~/.handoff/config.yml` — you do not need
to know or care which. That gives you `$CFG_ROLE`, `$CFG_PROJECT`, `$CFG_COORDINATION_CLONE`,
`$CFG_CONTRACT_PATH`. Everything lives under `P="$CFG_COORDINATION_CLONE/projects/$CFG_PROJECT"`.
Do NOT `cat`, `find`, or guess at `~/.handoff/config.yml` — that is wrong under `--local` and
wastes turns.

## Run these
1. **Decide if a handoff is even needed.** Inspect the local feature-branch diff
   (`git diff main...HEAD`). If nothing touches the shared contract and you need nothing from
   the other team, STOP and tell the human "no handoff needed."
2. **Edit the contract.** In the coordination clone, edit `$P/$CFG_CONTRACT_PATH` to the new shape.
3. **Classify the change.** Run `~/.handoff/tools/contract_diff.sh <old> <new>` where `<old>` is
   `git show main:projects/$CFG_PROJECT/$CFG_CONTRACT_PATH`. Capture the changelog + whether BREAKING.
4. **Scaffold + fill the manifest.**
   `ID=$(~/.handoff/tools/new_handoff.sh "$CFG_ROLE" "$P/handoffs")` then fill every frontmatter
   field, set `breaking` from step 3 (and `migration` if breaking), and paste the changelog into
   the "Change detail" section so the recipient — who can't open your repo — sees it. Confirm
   the intent/summary with the human.
5. **Submit (one command).** `~/.handoff/tools/handoff_submit.sh "$P/handoffs/$ID.md"`
   — validates, pins the contract hash, branches `proposal/<project>/$ID`, commits, pushes,
   opens the PR. (It never pushes to `main`.)
6. **Report.** Give the human the PR URL; tell the other side to run `/handoff-check`.

## Guardrails
- One handoff = one coherent change; split unrelated changes.
- Keep the manifest self-contained — assume the recipient cannot read your repo.
- Stop for human approval before merge; that is the human-in-the-loop gate.
