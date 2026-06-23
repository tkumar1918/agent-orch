# Local handoff MCP server

A stdio MCP server that exposes the handoff workflow as **typed tools**, so the agent calls
`handoff_create(...)` instead of running bash. It is a thin wrapper over the same scripts in
`~/.handoff/tools/` — **git stays the source of truth**; this only changes the interface.

Use it if you want the workflow in Claude Desktop / an IDE / any MCP client, or just cleaner
tool calls. The bash skills keep working with or without it.

## Tools
| Tool | Does |
|---|---|
| `handoff_inbox()` | open handoffs to me + in-flight proposal PRs |
| `handoff_create(intent, required_actions, …, contract_yaml?, dry_run?)` | classify via oasdiff → write manifest → branch/commit/PR |
| `handoff_set_status(handoff_id, status, dry_run?)` | transition status via a small PR |
| `contract_sync(ref?)` | regen client / verify provider + drift report |

`handoff_create` auto-detects breaking changes with oasdiff and refuses to proceed on a
breaking change unless you pass a `migration` plan.

## Install
```bash
pip install -r mcp-server/requirements.txt        # mcp, pyyaml
# the server reads ~/.handoff/config.yml and runs scripts from ~/.handoff/tools/
# (set up by the laptop step in the top-level README)
```

## Register in Claude Code
Either the CLI:
```bash
claude mcp add handoff -- python3 /abs/path/to/agent-orch/mcp-server/server.py
```
or a project `.mcp.json`:
```json
{
  "mcpServers": {
    "handoff": {
      "command": "python3",
      "args": ["/abs/path/to/agent-orch/mcp-server/server.py"]
    }
  }
}
```
Override locations for testing via env: `HANDOFF_CONFIG`, `HANDOFF_TOOLS`.

## Smoke test (no SDK needed for the logic)
```bash
# the tool functions are importable without `mcp` installed:
HANDOFF_CONFIG=~/.handoff/config.yml HANDOFF_TOOLS=~/.handoff/tools \
  python3 -c "import sys; sys.path.insert(0,'mcp-server'); import server; print(server.handoff_inbox())"
```
