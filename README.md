# Multi-Repo Agent Handoff Orchestration

Keep an isolated **frontend** team and **backend** team aligned when they can't see each
other's repo. Each works human-in-the-loop with Claude Code on their own laptop; they
coordinate through a neutral third **coordination repo** that holds the shared API contract
and a structured, append-only log of handoff messages. PR review on that repo is the
human-in-the-loop approval gate.

**One coordination repo serves many projects** — each lives under `projects/<project>/`, so
you set it up once and add a project by adding a folder. (This assumes the projects share a
trust domain; everyone with repo access sees every project. For untrusted teams, use a
separate repo per project instead.)

> Full design: [docs/architecture.md](docs/architecture.md) ·
> [docs/workflow.md](docs/workflow.md) · [docs/state-machine.md](docs/state-machine.md)

## How it works (30 seconds)
1. Backend changes the API → `/handoff-create` updates the project's contract on a
   `proposal/<project>/<id>` branch, classifies breaking changes with `oasdiff`, drafts a
   **handoff manifest**, and (after human approval) opens a PR to the coordination repo.
2. Frontend runs `/handoff-check` → sees the handoff (even before merge), then
   `/contract-sync --ref proposal/<project>/<id>` regenerates its typed client + Prism mock and
   builds against the exact proposed shape — in parallel, without backend access.
3. Both approve & merge the contract PR; status flows `proposed → … → completed`. Everything
   is versioned and auditable.

## What's in here
| Path | Goes to | Purpose |
|---|---|---|
| `bootstrap.sh` | run once, by an admin | create + seed the coordination repo on GitHub and add both devs as collaborators |
| `enroll.sh` | run once, per project folder | clone the coordination repo + install skills/tools + write a project-local `.handoff/config.yml` |
| `coordination-repo-template/` | the shared 3rd GitHub repo | shared `_schema`/`_template`, per-project `projects/<project>/{contracts,handoffs,decisions}`, CODEOWNERS, CI |
| `claude-skills/` | each laptop's `~/.claude/skills/` | `/handoff-create`, `/handoff-check`, `/contract-sync` |
| `scripts/` | vendored into coordination repo `tools/` | `validate_handoff.py`, `contract_diff.sh`, `new_handoff.sh`, agent wrappers |
| `config/handoff.config.example.yml` | each project's `.handoff/config.yml` | role/identity/repo/**project** |
| `mcp-server/` | optional | local MCP server exposing the workflow as typed tools |
| `docs/` | reference | architecture, workflow, state machine |

## Setup
```bash
# 1. Create the coordination repo from the template, vendoring the tools.
cp -r coordination-repo-template/* /path/to/api-coordination/
mkdir -p /path/to/api-coordination/tools
cp scripts/* /path/to/api-coordination/tools/
# push it; give BOTH team owners write access; protect `main` with required Code Owner review.

# 2. Per project — run it INSIDE the project folder (clone + skills + tools + project-local config):
cd ~/work/web-app-ui && ./enroll.sh --repo acme/web-app-coordination --role frontend --identity alice --project web-app
# backend: cd into the backend folder, --role backend --identity bob   (same --repo and --project)
```

Config is **project-local**: `enroll.sh` writes `./.handoff/config.yml` into the folder you run it
in, and the agent uses the config of whatever folder it's running in (it walks up to find the
nearest `.handoff/config.yml`). There is no global config — so **one laptop serves many projects**
with zero ambiguity; just run `enroll.sh` once inside each project folder:
```bash
cd ~/work/shop-web  && ./enroll.sh --repo acme/handoff --role frontend --identity alice --project shop
cd ~/work/admin-web && ./enroll.sh --repo acme/handoff --role frontend --identity alice --project admin
```
Skills (`~/.claude/skills/`) and tools (`~/.handoff/tools/`) stay shared — identical code for every
project, like an installed CLI. Add `.handoff/` to each project's `.gitignore`.

<details><summary>…or the same thing by hand</summary>

```bash
cp -r claude-skills/* ~/.claude/skills/             # the /handoff-* skills (shared)
mkdir -p ~/.handoff/tools && cp scripts/* ~/.handoff/tools/   # the agent-run automation (shared)
git clone <coordination_repo> <coordination_clone>
mkdir -p .handoff && cp config/handoff.config.example.yml .handoff/config.yml   # in EACH project folder
$EDITOR .handoff/config.yml     # set role, identity, repo, clone path, and project
```
</details>

**One command per coordination repo** — [bootstrap.sh](bootstrap.sh) creates the repo from the
template (vendoring `tools/`) and adds both devs as collaborators. This is the natural fit when
your org provisions access per-repo (each dev is a collaborator scoped to one repo): give each
frontend/backend pair its own coordination repo with exactly those two devs.
```bash
./bootstrap.sh acme/web-app-coordination --private \
    --project web-app --collab alice-fe --collab bob-be
```
No clone needed — run it (and `enroll.sh`) straight from GitHub; the script fetches the rest of
the scaffold itself (needs `gh` authenticated):
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tkumar1918/agent-orch/main/bootstrap.sh) \
    acme/web-app-coordination --private --project web-app --collab alice-fe --collab bob-be

bash <(curl -fsSL https://raw.githubusercontent.com/tkumar1918/agent-orch/main/enroll.sh) \
    --repo acme/web-app-coordination --role frontend --identity alice --project web-app
```

**Add another project later** — no new repo, just a folder in the existing coordination repo
(`_schema` + `_template.md` are shared at the repo root; nothing to copy per project):
```bash
mkdir -p projects/<project>/{contracts,handoffs,decisions}
# add the first contract, add a CODEOWNERS block for projects/<project>/, commit, push.
# Each project folder working it sets `project: <project>` in its .handoff/config.yml.
```

The agent does the work, you just instruct it. The skills call one-command wrappers in
`~/.handoff/tools/`, so a session looks like:

```
You:    "hand this pagination change off to frontend"
Agent:  edits the contract, runs contract_diff.sh (flags BREAKING), drafts the manifest,
        runs handoff_submit.sh -> validates, branches, commits, pushes, opens the PR.
You:    approve/merge the PR.            # the only manual step (human-in-the-loop)

You:    "any handoffs for me?"
Agent:  runs handoff_inbox.sh, summarizes, runs contract_sync.sh (regen types + drift),
        runs handoff_status.sh <id> acknowledged.
```

Tooling the skills expect on PATH: `gh`, `oasdiff`, plus per-format consumers
(`openapi-typescript` + `@stoplight/prism-cli` for FE; `schemathesis` or `dredd` for BE).
Python deps for validation: `pip install jsonschema pyyaml`.

## Try it locally (no second laptop)
```bash
P=coordination-repo-template/projects/example-app

# Validate the sample handoff against the shared schema
python scripts/validate_handoff.py "$P/handoffs/2026-06-24-be-001-a1b2.md"

# Mint a new handoff from the shared template into a project
scripts/new_handoff.sh backend "$P/handoffs"

# Detect a breaking contract change (needs oasdiff installed)
scripts/contract_diff.sh old.yaml "$P/contracts/openapi.yaml"
```

## Optional: MCP server
Prefer typed tool calls (or want this in Claude Desktop / an IDE, not just Claude Code)?
[mcp-server/](mcp-server/) wraps the same scripts as MCP tools — `handoff_inbox`,
`handoff_create`, `handoff_set_status`, `contract_sync`. Git stays the source of truth; the
server is just a nicer interface. Register it with
`claude mcp add handoff -- python3 mcp-server/server.py`. See [mcp-server/README.md](mcp-server/README.md).

## Design choices
- **Git, not a service** — both agents are Git-native; PRs give async review + audit with no
  infra to run.
- **Contract-driven** — coordinate around the interface, not the code.
- **Self-contained handoffs** — embed the diff; the recipient can't open your repo.
- **Human-in-the-loop** — agents draft, humans approve via PR review.
- **Format-agnostic** — OpenAPI by default; swap `oasdiff` for `graphql-inspector` / `buf`.
