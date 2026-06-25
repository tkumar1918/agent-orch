---
handoff_id: YYYY-MM-DD-<side>-NNN-<rand>  # mint with scripts/new_handoff.sh
from: backend                            # producer: frontend | backend
to: frontend                             # consumer: frontend | backend
created_by: <human name> (human-approved via Claude Code)
status: proposed                         # proposed|acknowledged|in-progress|completed|blocked|rejected
contract_status: proposed                # proposed (on a branch) | released (merged to main)
contract_branch: proposal/<handoff_id>   # required when contract_status: proposed
contract_version: <pinned commit sha>    # EXACT sha — not "latest"
breaking: false                          # set by oasdiff, confirmed by a human
severity: low                            # low | medium | high
intent: "<one line: what changed and why>"
affects:
  - target: "<e.g. GET /orders>"
    change: "<what changed about it>"
required_actions:
  - "<concrete thing the recipient must do>"
migration:                               # REQUIRED when breaking: true
  - "<backward-compat window / how to migrate>"
deadline: YYYY-MM-DD                      # optional
links:
  - "contract PR: <coordination-repo URL>"
  - "source PR: <URL — may be inaccessible to recipient; see embedded summary>"
---

## Summary
<Self-contained explanation. The recipient may NOT be able to open your repo's PR,
so say everything here.>

## What you need to do
- [ ] <mirror required_actions as a checklist>

## Verification
<How the recipient proves conformance: regen the typed client from the contract,
run contract tests.>

## Change detail (embedded — recipient can't open the source PR)
```
<paste `oasdiff changelog` output here>
```
