# Architecture

## Problem
Two GitHub repos (frontend, backend) owned by separate teams with **no cross-repo access**.
Work is human-in-the-loop with Claude Code on isolated laptops. When one side changes the
shared API, the other has no reliable, structured way to learn what changed, why, and what
they must do — so breaking changes surface only at integration time.

## Principle: coordinate around the contract, not the code
Frontend and backend are coupled *only* through their shared interface. So the system is
organized around a **shared contract** plus **structured handoff messages**, exchanged
through a neutral third Git repository.

## The three pillars

### 1. Coordination repo (the neutral ground / message bus)
A third GitHub repo both owners can access — the only shared surface. **One repo serves many
projects**; each lives under `projects/<project>/`.

```
api-coordination/
├── _schema/handoff.schema.json   # shared manifest schema (all projects)
├── _template.md                  # shared blank manifest
├── projects/
│   └── <project>/
│       ├── contracts/openapi.yaml  # SINGLE SOURCE OF TRUTH for this project's interface
│       ├── handoffs/*.md           # append-only log of handoff messages
│       └── decisions/*.md          # cross-team ADRs
├── tools/                        # vendored validate_handoff.py / contract_diff.sh / wrappers
├── CODEOWNERS                    # per-project: contract changes need BOTH teams' approval
└── .github/workflows/            # schema validation + oasdiff breaking-change gate
```

Add a project = add a `projects/<project>/` folder + a CODEOWNERS block. No new repo.

Why Git? Both agents are already Git-native; it is versioned, diffable, auditable, async
across timezones, and the **PR review is the human-in-the-loop approval gate** — no new
service to run.

### 2. Handoff Manifest (the structured message)
Markdown + YAML frontmatter: agent-parseable and human-readable. Self-contained (embeds the
oasdiff changelog) because the recipient usually cannot open the producer's source PR.
Validated by the shared `_schema/handoff.schema.json`. See [state-machine.md](state-machine.md).

### 3. Claude Code skills (the agent interface)
`/handoff-create`, `/handoff-check`, `/contract-sync` — each laptop drives the coordination
repo through these. They draft and propose; humans approve. See [workflow.md](workflow.md).

## Access model (satisfies "no direct repo access")
- FE owner: write to FE repo + coordination repo.
- BE owner: write to BE repo + coordination repo.
- Neither can see the other's product repo. Cross-repo PR links in a handoff are backed by
  an embedded summary, since the link target may be unreachable for the recipient.

## Reliability mechanisms
- JSON-Schema-validated manifests (CI + local) — malformed messages can't merge.
- `oasdiff` breaking-change gate — a breaking contract change can't merge without a
  `breaking: true` handoff.
- Status state machine with illegal transitions rejected.
- Pinned `contract_version` SHA + drift detection in `/contract-sync`.
- Contract tests on both sides (FE: typed client + Prism mock; BE: provider verification).
- Append-only git history = full audit trail.

## Format-agnostic
OpenAPI is the worked example. Swap the contract tooling for GraphQL (`graphql-inspector`)
or gRPC (`buf`); the manifest, transport, and workflow are unchanged.

## Optional later extensions
- Real-time notify layer (Slack/webhook/push) on top of the Git source of truth.
- A custom MCP server exposing `get_open_handoffs` / `submit_handoff` for richer integration.
