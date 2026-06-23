#!/usr/bin/env python3
"""Local MCP server for cross-repo handoffs (stdio transport).

Thin, typed wrapper over the SAME scripts the /handoff-* skills use — git remains the
source of truth; this just gives the agent clean tool calls instead of shelling out.

Tools:
  handoff_inbox            open handoffs to me + in-flight proposal PRs
  handoff_create           draft contract change -> classify -> manifest -> PR
  handoff_set_status       transition a handoff's status (opens a small PR)
  contract_sync            regen client / verify provider + drift report

Config: reads ~/.handoff/config.yml (override with $HANDOFF_CONFIG).
Scripts: found in ~/.handoff/tools/ (override with $HANDOFF_TOOLS).
Run: python3 server.py   (needs: pip install mcp pyyaml)
"""
from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path

import yaml

# FastMCP is optional at import time so the tool logic stays unit-testable without the SDK.
try:
    from mcp.server.fastmcp import FastMCP

    _mcp: "FastMCP | None" = FastMCP("handoff")
    tool = _mcp.tool
except ImportError:  # pragma: no cover - exercised only when mcp isn't installed
    _mcp = None

    def tool(*_a, **_k):
        def deco(f):
            return f

        return deco


TOOLS = Path(os.environ.get("HANDOFF_TOOLS", Path.home() / ".handoff" / "tools"))


def _config() -> dict:
    path = Path(os.environ.get("HANDOFF_CONFIG", Path.home() / ".handoff" / "config.yml"))
    if not path.is_file():
        raise FileNotFoundError(f"missing config: {path}")
    cfg = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    cfg["coordination_clone"] = os.path.expanduser(cfg.get("coordination_clone", ""))
    cfg.setdefault("contract_path", "contracts/openapi.yaml")
    return cfg


def _run(args: list[str], cwd: str | None = None, extra_env: dict | None = None) -> str:
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)
    p = subprocess.run(args, cwd=cwd, capture_output=True, text=True, env=env)
    out = (p.stdout + p.stderr).strip()
    return out if p.returncode == 0 else f"[exit {p.returncode}]\n{out}"


@tool()
def handoff_inbox() -> str:
    """List open handoffs addressed to this side, plus in-flight proposal PRs."""
    return _run(["bash", str(TOOLS / "handoff_inbox.sh")])


@tool()
def contract_sync(ref: str = "") -> str:
    """Sync local code to the shared contract and report drift.

    ref: optional 'proposal/<id>' (or sha) to build against an in-flight proposal;
         empty = coordination main (released contract).
    """
    args = ["bash", str(TOOLS / "contract_sync.sh")]
    if ref:
        args += ["--ref", ref]
    return _run(args)


@tool()
def handoff_set_status(handoff_id: str, status: str, dry_run: bool = False) -> str:
    """Transition a handoff status (acknowledged|in-progress|completed|blocked|rejected).

    Opens a small PR recording the change.
    """
    return _run(
        ["bash", str(TOOLS / "handoff_status.sh"), handoff_id, status],
        extra_env={"DRY_RUN": "1"} if dry_run else None,
    )


@tool()
def handoff_create(
    intent: str,
    required_actions: list[str],
    summary: str = "",
    to: str = "",
    breaking: bool | None = None,
    migration: list[str] | None = None,
    severity: str = "",
    affects: list[dict] | None = None,
    deadline: str = "",
    contract_yaml: str = "",
    dry_run: bool = False,
) -> str:
    """Create a handoff for the other team and open a PR.

    Precondition: edit the contract in the coordination clone first, OR pass the full new
    contract text as `contract_yaml`. This tool then classifies the change with oasdiff,
    writes the manifest, validates it, branches, commits and opens the PR.

    breaking: leave None to auto-detect via oasdiff (recommended). If breaking, `migration`
    is required.
    """
    cfg = _config()
    clone = Path(cfg["coordination_clone"])
    contract_rel = cfg["contract_path"]
    contract_abs = clone / contract_rel
    role = cfg.get("role", "")
    to = to or ("frontend" if role == "backend" else "backend")
    identity = cfg.get("identity", "agent")

    if not clone.is_dir():
        return f"coordination clone not found: {clone}"

    if contract_yaml:
        contract_abs.write_text(contract_yaml, encoding="utf-8")

    # Old contract = the version on main; new = working tree (just edited).
    old = subprocess.run(
        ["git", "show", f"main:{contract_rel}"], cwd=clone, capture_output=True, text=True
    )
    with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as tf:
        tf.write(old.stdout)
        old_path = tf.name

    diff = subprocess.run(
        ["bash", str(TOOLS / "contract_diff.sh"), old_path, str(contract_abs)],
        capture_output=True,
        text=True,
        env=os.environ.copy(),
    )
    changelog = (diff.stdout + diff.stderr).strip()
    detected_breaking = diff.returncode == 1
    if breaking is None:
        breaking = detected_breaking
    if breaking and not migration:
        return (
            "This change is BREAKING but no `migration` was provided. Re-call with a "
            "migration plan (e.g. a backward-compat window).\n\n" + changelog
        )
    severity = severity or ("high" if breaking else "low")

    # Mint a unique id (new_handoff.sh prints the path it created).
    minted = _run(["bash", str(TOOLS / "new_handoff.sh"), role, str(clone / "handoffs")])
    manifest_path = Path(minted.splitlines()[-1].strip())
    hid = manifest_path.stem

    fm = {
        "handoff_id": hid,
        "from": role,
        "to": to,
        "created_by": f"{identity} (via MCP/agent)",
        "status": "proposed",
        "contract_status": "proposed",
        "contract_branch": f"proposal/{hid}",
        "contract_version": "pending",  # handoff_submit.sh pins the real hash before validate
        "breaking": bool(breaking),
        "severity": severity,
        "intent": intent,
        "affects": affects or [],
        "required_actions": list(required_actions),
    }
    if migration:
        fm["migration"] = list(migration)
    if deadline:
        fm["deadline"] = deadline

    front = yaml.safe_dump(fm, sort_keys=False, allow_unicode=True).strip()
    actions_md = "\n".join(f"- [ ] {a}" for a in required_actions)
    body = (
        f"## Summary\n{summary or intent}\n\n"
        f"## What you need to do\n{actions_md}\n\n"
        f"## Verification\nRun /contract-sync (use --ref {fm['contract_branch']} while the "
        f"contract is on its branch), regenerate types, and run contract tests.\n\n"
        f"## Change detail (embedded — recipient can't open the source PR)\n"
        f"```\n{changelog}\n```\n"
    )
    manifest_path.write_text(f"---\n{front}\n---\n\n{body}", encoding="utf-8")

    submit = _run(
        ["bash", str(TOOLS / "handoff_submit.sh"), str(manifest_path)],
        extra_env={"DRY_RUN": "1"} if dry_run else None,
    )
    return f"handoff {hid} (breaking={breaking}, severity={severity})\n{submit}"


if __name__ == "__main__":
    if _mcp is None:
        raise SystemExit("MCP SDK missing. Run: pip install mcp pyyaml")
    _mcp.run()  # stdio transport
