#!/usr/bin/env python3
"""List open handoffs addressed to a role, newest first.

    _inbox.py <handoffs_dir> <role>
"""
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("Missing dep. Run: pip install pyyaml")

OPEN = {"proposed", "acknowledged", "in-progress", "blocked"}


def frontmatter(path: Path):
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return None
    parts = text.split("---", 2)
    if len(parts) < 3:
        return None
    data = yaml.safe_load(parts[1])
    return data if isinstance(data, dict) else None


def main(argv):
    if len(argv) < 2:
        sys.exit("usage: _inbox.py <handoffs_dir> <role>")
    handoffs, role = Path(argv[0]), argv[1]
    rows = []
    for f in sorted(handoffs.glob("[!_]*.md"), reverse=True):
        m = frontmatter(f)
        if m and m.get("to") == role and m.get("status") in OPEN:
            rows.append(m)
    if not rows:
        print("  (none)")
        return 0
    for m in rows:
        brk = "BREAKING" if m.get("breaking") else "non-breaking"
        print(f"  [{m.get('status')}] {m.get('handoff_id')}  ({brk}, sev={m.get('severity')})")
        print(f"      intent: {m.get('intent')}")
        for a in m.get("required_actions") or []:
            print(f"      - {a}")
        if m.get("deadline"):
            print(f"      deadline: {m.get('deadline')}")
        if m.get("contract_status") == "proposed":
            print(f"      contract still on branch: {m.get('contract_branch')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
