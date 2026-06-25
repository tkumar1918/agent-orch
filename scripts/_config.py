#!/usr/bin/env python3
"""Emit ~/.handoff/config.yml as shell-safe CFG_* assignments for the wrappers.

    eval "$(python3 _config.py)" || exit 1

Override the path with $HANDOFF_CONFIG (used by tests).
"""
import os
import shlex
import sys

try:
    import yaml
except ImportError:
    sys.stderr.write("Missing dep. Run: pip install pyyaml\n")
    sys.exit(1)

path = os.environ.get("HANDOFF_CONFIG", os.path.expanduser("~/.handoff/config.yml"))
if not os.path.isfile(path):
    sys.stderr.write(f"missing config: {path} (copy config/handoff.config.example.yml)\n")
    sys.exit(1)

d = yaml.safe_load(open(path, encoding="utf-8")) or {}


def emit(var: str, key: str, default: str = "") -> None:
    v = d.get(key, default)
    if isinstance(v, str) and ("/" in v or v.startswith("~")):
        v = os.path.expanduser(v)
    print(f"{var}={shlex.quote(str(v))}")


emit("CFG_ROLE", "role")
emit("CFG_PROJECT", "project")
emit("CFG_IDENTITY", "identity")
emit("CFG_COORDINATION_REPO", "coordination_repo")
emit("CFG_COORDINATION_CLONE", "coordination_clone")
emit("CFG_CONTRACT_PATH", "contract_path", "contracts/openapi.yaml")
emit("CFG_CONTRACT_FORMAT", "contract_format", "openapi")
emit("CFG_CLIENT_TYPES_OUT", "client_types_out", "src/api/types.ts")
emit("CFG_MOCK_PORT", "mock_port", "4010")
