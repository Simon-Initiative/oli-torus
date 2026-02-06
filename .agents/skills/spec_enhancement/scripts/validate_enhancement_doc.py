#!/usr/bin/env python3
"""Validate enhancement markdown docs for required structure."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REQUIRED_HEADINGS = [
    "## Problem",
    "## Scope",
    "## Acceptance Criteria",
    "## Risks",
    "## Test Plan",
    "## Rollout Notes",
    "## Out of Scope",
]

TODO_PATTERN = re.compile(r"\b(?:TODO|TBD|FIXME)\b", re.IGNORECASE)
AC_PATTERN = re.compile(r"^\s*-\s*AC-\d{3}\s*:", re.MULTILINE)


def validate(path: Path) -> list[str]:
    errors: list[str] = []
    if not path.exists():
        return [f"File not found: {path}"]
    if not path.is_file():
        return [f"Path is not a file: {path}"]

    text = path.read_text(encoding="utf-8")

    for heading in REQUIRED_HEADINGS:
        if heading not in text:
            errors.append(f"Missing required heading: {heading}")

    if TODO_PATTERN.search(text):
        errors.append("Unresolved marker found: TODO/TBD/FIXME")

    if not AC_PATTERN.search(text):
        errors.append("Acceptance Criteria must include at least one AC-### bullet item")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate enhancement markdown doc")
    parser.add_argument("doc_path", help="Path to enhancement markdown file")
    args = parser.parse_args()

    path = Path(args.doc_path)
    errors = validate(path)

    if errors:
        print("Validation failed:")
        for e in errors:
            print(f"- {e}")
        return 1

    print(f"Validation passed: {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
