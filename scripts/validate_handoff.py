#!/usr/bin/env python3
"""Validate handoff manifests against handoffs/_schema/handoff.schema.json.

Single source of truth shared by CI (validate-handoffs.yml) and the local
/handoff-create skill. Usage:

    python validate_handoff.py handoffs/2026-06-24-be-001.md [more.md ...]

Exit code 0 = all valid; 1 = at least one invalid (errors printed per file).
Vendor this file into the coordination repo as tools/validate_handoff.py.
"""
import sys
from pathlib import Path

try:
    import yaml
    from jsonschema import Draft202012Validator
except ImportError:
    sys.exit("Missing deps. Run: pip install jsonschema pyyaml")


def find_schema(manifest: Path) -> Path:
    """Schema is shared at <coordination-repo-root>/_schema/handoff.schema.json. Walk up
    from the manifest (manifests live at projects/<project>/handoffs/<id>.md)."""
    d = manifest.resolve().parent
    while True:
        cand = d / "_schema" / "handoff.schema.json"
        if cand.is_file():
            return cand
        if d.parent == d:
            break
        d = d.parent
    fallback = (
        Path(__file__).resolve().parent.parent
        / "coordination-repo-template/_schema/handoff.schema.json"
    )
    if fallback.is_file():
        return fallback
    sys.exit(f"Could not locate _schema/handoff.schema.json above {manifest}")


def _normalize(value):
    """YAML turns unquoted ISO dates into date objects; render them back to strings
    so they validate against the schema's string+pattern fields."""
    import datetime

    if isinstance(value, (datetime.date, datetime.datetime)):
        return value.isoformat()
    if isinstance(value, dict):
        return {k: _normalize(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_normalize(v) for v in value]
    return value


def parse_frontmatter(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        raise ValueError("file does not start with '---' frontmatter")
    parts = text.split("---", 2)
    if len(parts) < 3:
        raise ValueError("missing closing '---' for frontmatter")
    data = yaml.safe_load(parts[1])
    if not isinstance(data, dict):
        raise ValueError("frontmatter is not a YAML mapping")
    return {k: _normalize(v) for k, v in data.items()}


def main(argv: list[str]) -> int:
    if not argv:
        print("usage: validate_handoff.py <manifest.md> [...]", file=sys.stderr)
        return 2
    import json

    failures = 0
    for arg in argv:
        path = Path(arg)
        try:
            data = parse_frontmatter(path)
        except Exception as e:  # noqa: BLE001
            print(f"FAIL {path}: {e}")
            failures += 1
            continue
        schema = json.loads(find_schema(path).read_text(encoding="utf-8"))
        errors = sorted(
            Draft202012Validator(schema).iter_errors(data), key=lambda e: list(e.path)
        )
        # Cross-field sanity not expressible in schema: filename must match handoff_id.
        if path.stem != data.get("handoff_id"):
            print(f"FAIL {path}: filename must equal handoff_id '{data.get('handoff_id')}'")
            failures += 1
            continue
        if errors:
            print(f"FAIL {path}:")
            for err in errors:
                loc = "/".join(str(p) for p in err.path) or "(root)"
                print(f"   - {loc}: {err.message}")
            failures += 1
        else:
            print(f"OK   {path}  [{data['from']} -> {data['to']}, status={data['status']}]")

    if failures:
        print(f"\n{failures} invalid manifest(s).")
        return 1
    print("\nAll manifests valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
