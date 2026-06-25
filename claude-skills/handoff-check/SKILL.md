---
name: handoff-check
description: >
  Check for incoming handoffs addressed to this team, including in-flight proposal PRs. Use at
  the start of a session or when the other team says they sent something. The AGENT pulls,
  lists, summarizes, flags drift, and (on confirm) acknowledges + syncs. The human just reads
  the summary and confirms.
---

# /handoff-check

**Automation contract:** you (the agent) run all commands. Tools live in `~/.handoff/tools/`.

## Run these
1. **List the inbox (one command).** `~/.handoff/tools/handoff_inbox.sh` — pulls the
   coordination repo and prints open handoffs `to: <my role>` (merged) plus open `proposal/*`
   PRs (in-flight, before merge).
2. **Summarize for the human.** For each open handoff: id, from, intent, breaking?, severity,
   required actions, deadline, and whether the contract is still on a branch.
3. **Propose a plan.** For the top-priority handoff, draft a concrete local task list covering
   each required action.
4. **Sync the contract.** Run `~/.handoff/tools/contract_sync.sh` (add
   `--ref <contract_branch>` when the handoff's `contract_status` is `proposed`). This
   regenerates the client and reports any drift since your last sync.
5. **Acknowledge (after human confirm).**
   `~/.handoff/tools/handoff_status.sh <id> acknowledged` commits the status straight to main
   (no PR — a status marker isn't a contract change). Move to `in-progress` when you start and
   `completed` when done (same command).

## Notes
- Acknowledging only records you have SEEN it; it is a real human-confirmed step.
- If you disagree with a proposed contract, comment on the proposal PR rather than coding
  against a shape you will not honor.
