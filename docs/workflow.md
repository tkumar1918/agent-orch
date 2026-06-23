# Workflow

## Branching & version-pinning (parallel dev across branches)
The contract has its own branch lifecycle in the coordination repo, mirroring the feature
branches in the two product repos — so FE and BE develop in parallel without waiting, while
pinning prevents silent drift.

```
 Coordination repo:   main ──────●────────────●──────▶   (released contracts)
                                  └─ proposal/be-001 ─┘    (merge = release)
                                       ▲        ▲
 Backend repo:   feat/orders-pagination┘        │         (BE implements vs proposal)
 Frontend repo:  feat/orders-pagination─────────┘         (FE syncs --ref proposal/be-001)
```

- **Phase A — Propose.** `/handoff-create` opens a `proposal/<id>` branch + PR carrying the
  new contract + manifest (`contract_status: proposed`). Teams negotiate the shape on that
  PR — the cheapest place to disagree, before integration.
- **Phase B — Release.** When both agree and implementations land, the PR merges to `main`;
  the manifest flips to `contract_status: released`. `main` always equals the live contract.
- **Parallel dev.** FE need not wait for merge: `/contract-sync --ref proposal/<id>` builds
  against the pinned proposal SHA while BE is still implementing.
- **Drift.** `contract_version` is an exact SHA. If the proposal branch is revised the SHA
  bumps; `/contract-sync` / `/handoff-check` run oasdiff between SHAs and report it.
- **Deploy skew.** The `migration` field's backward-compat window covers the period where
  FE's main has new code but BE prod still serves old.

## End-to-end example: backend adds breaking pagination

1. **Implement.** BE dev + Claude Code implement pagination in the backend repo feature
   branch.
2. **Create handoff.** `/handoff-create`: agent updates `contracts/openapi.yaml` on
   `proposal/be-001`, `contract_diff.sh` flags BREAKING + captures the changelog, drafts
   `handoffs/2026-06-24-be-001.md`. Human reviews/edits/approves.
3. **Open PR.** Agent opens a coordination-repo PR (contract + manifest). CI runs oasdiff +
   schema validation; CODEOWNERS requires BOTH teams. Reviewers approve → merge → handoff is
   `proposed` and visible to FE.
4. **Receive.** FE dev runs `/handoff-check`: agent summarizes intent + required actions,
   transitions to `acknowledged`, then `/contract-sync --ref proposal/be-001` regenerates
   `types.ts` and refreshes the Prism mock.
5. **Build.** FE implements against the mock; contract tests pass. Status → `in-progress`.
6. **Done.** FE marks `completed`; both sides aligned, whole exchange auditable in git.

## Who runs what
| Action | Skill | Side |
|---|---|---|
| Announce a contract/behavior change | `/handoff-create` | producer |
| Triage incoming changes | `/handoff-check` | consumer |
| Regenerate client / verify provider / detect drift | `/contract-sync` | both |

## Human-in-the-loop gates
- Agents draft, never auto-send; a human approves before any PR is opened.
- Contract-change PRs require both teams via CODEOWNERS + branch protection.
- Status transitions (acknowledge / in-progress / complete) are explicit human actions.
