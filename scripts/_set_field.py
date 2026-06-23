#!/usr/bin/env python3
"""Set one top-level frontmatter field in a handoff manifest, preserving the body.

    _set_field.py <manifest.md> <key> <value>
"""
import re
import sys
from pathlib import Path


def main(argv):
    if len(argv) < 3:
        sys.exit("usage: _set_field.py <manifest.md> <key> <value>")
    path = Path(argv[0])
    key, value = argv[1], argv[2]
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        sys.exit(f"{path}: not a frontmatter file")
    parts = text.split("---", 2)
    if len(parts) < 3:
        sys.exit(f"{path}: missing closing '---'")
    fm = parts[1]
    new_line = f"{key}: {value}"
    pattern = re.compile(rf"(?m)^{re.escape(key)}:.*$")
    if pattern.search(fm):
        fm = pattern.sub(new_line, fm, count=1)
    else:  # append before the closing fence
        fm = fm.rstrip("\n") + f"\n{new_line}\n"
    path.write_text("---" + fm + "---" + parts[2], encoding="utf-8")


if __name__ == "__main__":
    main(sys.argv[1:])
