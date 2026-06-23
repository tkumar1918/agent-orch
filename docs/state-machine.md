# Handoff status state machine

```
proposed ──▶ acknowledged ──▶ in-progress ──▶ completed
   │              │                │
   └──▶ rejected  └──▶ blocked ◀───┘
```

| Status | Meaning | Who sets it | How |
|---|---|---|---|
| `proposed` | Handoff sent; awaiting the recipient. | producer | merge of the create PR |
| `acknowledged` | Recipient has seen and understood it. | consumer | `/handoff-check` → PR |
| `in-progress` | Recipient is implementing the required actions. | consumer | PR |
| `blocked` | Recipient cannot proceed (needs info / a contract change). | consumer | PR + comment |
| `completed` | Required actions done; both sides aligned. | consumer | PR |
| `rejected` | Handoff declined (wrong, duplicate, not needed). | consumer | PR + reason |

## Rules
- Transitions are explicit, human-confirmed commits — both sides always see live state.
- Legal transitions only (enforceable in `validate-handoffs.yml` by diffing against base):
  - `proposed → acknowledged | rejected`
  - `acknowledged → in-progress | blocked | rejected`
  - `in-progress → completed | blocked`
  - `blocked → in-progress | rejected`
- `completed` and `rejected` are terminal. A follow-up change is a NEW handoff.
- Manifests are updated in place; git history preserves the full audit trail (append-only).

## Two orthogonal fields
- `status` — progress of the **handoff** (above).
- `contract_status` — lifecycle of the **contract**: `proposed` (on a branch) → `released`
  (merged to `main`). A handoff can be `in-progress` while its contract is still `proposed`
  (parallel development against a proposal branch).
