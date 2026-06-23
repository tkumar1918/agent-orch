---
name: contract-sync
description: >
  Sync local code to the shared API contract from the coordination repo and report drift.
  Frontend regenerates the typed client + mock; backend verifies its implementation against
  the spec. The AGENT runs it; use after /handoff-check, when starting work against a proposal,
  or to detect drift.
---

# /contract-sync

**Automation contract:** you (the agent) run the command. Tools live in `~/.handoff/tools/`.

## Run this
- `~/.handoff/tools/contract_sync.sh [--ref <branch|sha>]`
  - default ref is coordination `main` (released contract);
  - `--ref proposal/<id>` builds against an in-flight proposal;
  - it pulls the contract, **reports drift vs your last sync** via oasdiff, then:
    - **frontend:** regenerates `client_types_out` and prints the Prism mock command;
    - **backend:** prints the provider-verification command (schemathesis/dredd);
  - and records the synced contract hash in `~/.handoff/last_sync`.

## After running
- Report the ref/hash synced, what was regenerated, and any drift.
- If drift shows your implementation diverged from the contract, that is a handoff — run
  `/handoff-create`; do not silently change the contract under the other team.
- GraphQL/gRPC: swap the codegen + use `graphql-inspector` / `buf` for diffing.
