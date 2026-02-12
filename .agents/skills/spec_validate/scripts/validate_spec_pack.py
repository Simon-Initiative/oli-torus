#!/usr/bin/env python3
"""Validate Torus spec-pack markdown artifacts.

Checks:
- required headings exist
- unresolved TODO/TBD/FIXME markers do not exist
- acceptance criteria count > 0 (PRD/design)
- plan phases are numbered and each phase has Definition of Done
- markdown links are valid (local paths + anchors; optional external URL checks)
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Tuple
from urllib.parse import urlparse
from urllib.request import Request, urlopen

TODO_RE = re.compile(r"\b(TODO|TBD|FIXME)\b", re.IGNORECASE)
AC_RE = re.compile(r"\bAC-\d{3}[A-Za-z]?\b")
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
PHASE_HEADING_RE = re.compile(r"^##+\s*Phase\s+(\d+)\s*:\s*(.+)$", re.IGNORECASE | re.MULTILINE)


@dataclass
class ValidationResult:
    errors: List[str]
    warnings: List[str]

    def add_error(self, msg: str) -> None:
        self.errors.append(msg)

    def add_warning(self, msg: str) -> None:
        self.warnings.append(msg)


def normalize_heading(text: str) -> str:
    t = text.strip().lower()
    t = re.sub(r"^\d+(?:\.\d+)*\s*", "", t)
    t = t.replace("*", "").replace("`", "")
    t = re.sub(r"\s+", " ", t)
    return t


def slugify_heading(text: str) -> str:
    t = normalize_heading(text)
    t = re.sub(r"[^a-z0-9\s-]", "", t)
    t = t.replace(" ", "-")
    t = re.sub(r"-+", "-", t).strip("-")
    return t


def extract_headings(content: str) -> List[str]:
    return [normalize_heading(m.group(2)) for m in HEADING_RE.finditer(content)]


def check_required_headings(content: str, required: Iterable[str], file_label: str, result: ValidationResult) -> None:
    headings = extract_headings(content)
    for needed in required:
        needed_norm = normalize_heading(needed)
        if not any(needed_norm in h for h in headings):
            result.add_error(f"{file_label}: missing required heading matching '{needed}'")


def check_todo_markers(content: str, file_label: str, result: ValidationResult) -> None:
    if TODO_RE.search(content):
        result.add_error(f"{file_label}: unresolved TODO/TBD/FIXME marker found")


def check_ac_count(content: str, file_label: str, result: ValidationResult) -> None:
    count = len(AC_RE.findall(content))
    if count <= 0:
        result.add_error(f"{file_label}: acceptance criteria count must be > 0")


def split_link_target(target: str) -> Tuple[str, str]:
    if "#" in target:
        path_part, anchor = target.split("#", 1)
        return path_part, anchor
    return target, ""


def anchors_for_file(path: Path) -> set[str]:
    content = path.read_text(encoding="utf-8")
    anchors = set()
    for m in HEADING_RE.finditer(content):
        anchors.add(slugify_heading(m.group(2)))
    return anchors


def check_external_url(url: str, timeout: float) -> Tuple[bool, str]:
    try:
        req = Request(url, method="HEAD")
        with urlopen(req, timeout=timeout) as resp:
            code = getattr(resp, "status", 200)
            if code >= 400:
                return False, f"HTTP {code}"
            return True, "ok"
    except Exception as e:  # noqa: BLE001
        return False, str(e)


def check_links(content: str, file_path: Path, check_external: bool, timeout: float, result: ValidationResult) -> None:
    for link in LINK_RE.findall(content):
        raw = link.strip()
        if not raw:
            continue
        if raw.startswith("mailto:") or raw.startswith("tel:"):
            continue

        parsed = urlparse(raw)
        if parsed.scheme in ("http", "https"):
            if not parsed.netloc:
                result.add_error(f"{file_path}: invalid URL '{raw}'")
                continue
            if check_external:
                ok, detail = check_external_url(raw, timeout)
                if not ok:
                    result.add_error(f"{file_path}: external link check failed for '{raw}' ({detail})")
            continue

        link_path, anchor = split_link_target(raw)

        if raw.startswith("#"):
            anchor_name = raw[1:]
            anchors = {slugify_heading(m.group(2)) for m in HEADING_RE.finditer(content)}
            if anchor_name.lower() not in anchors:
                result.add_error(f"{file_path}: missing local anchor '#{anchor_name}'")
            continue

        target_path = (file_path.parent / link_path).resolve()
        if not target_path.exists():
            result.add_error(f"{file_path}: linked path not found '{raw}'")
            continue

        if anchor:
            anchors = anchors_for_file(target_path)
            if anchor.lower() not in anchors:
                result.add_error(f"{file_path}: anchor '#{anchor}' not found in '{target_path}'")


def check_plan_phases(content: str, file_label: str, result: ValidationResult) -> None:
    phases = list(PHASE_HEADING_RE.finditer(content))
    if not phases:
        result.add_error(f"{file_label}: no numbered phase headings found (expected '## Phase <n>: ...')")
        return

    numbers = [int(m.group(1)) for m in phases]
    if len(set(numbers)) != len(numbers):
        result.add_error(f"{file_label}: duplicate phase numbers detected")

    for idx, match in enumerate(phases):
        start = match.start()
        end = phases[idx + 1].start() if idx + 1 < len(phases) else len(content)
        phase_block = content[start:end]
        if re.search(r"definition\s+of\s+done", phase_block, re.IGNORECASE) is None:
            result.add_error(
                f"{file_label}: phase {match.group(1)} ('{match.group(2).strip()}') missing 'Definition of Done'"
            )


def validate_file(file_path: Path, doc_type: str, check_external: bool, timeout: float) -> ValidationResult:
    result = ValidationResult(errors=[], warnings=[])
    label = str(file_path)

    if not file_path.exists():
        result.add_error(f"{label}: file does not exist")
        return result

    content = file_path.read_text(encoding="utf-8")

    required_by_type = {
        "prd": [
            "overview",
            "background & problem statement",
            "goals & non-goals",
            "users & use cases",
            "functional requirements",
            "acceptance criteria",
            "non-functional requirements",
            "data model & apis",
            "feature flagging",
            "risks & mitigations",
            "open questions & assumptions",
        ],
        "fdd": [
            "executive summary",
            "requirements & assumptions",
            "torus context summary",
            "proposed design",
            "interfaces",
            "data model & storage",
            "failure modes & resilience",
            "observability",
            "security & privacy",
            "testing strategy",
            "risks & mitigations",
            "open questions",
        ],
        "plan": [
            "clarifications",
            "phase gate summary",
        ],
        "design": [
            "slice summary",
            "ac coverage",
            "responsibilities & boundaries",
            "interfaces & signatures",
            "data flow & edge cases",
            "test plan",
            "risks & open questions",
            "definition of done",
        ],
    }

    if doc_type in required_by_type:
        check_required_headings(content, required_by_type[doc_type], label, result)

    check_todo_markers(content, label, result)
    check_links(content, file_path, check_external, timeout, result)

    if doc_type in {"prd", "design"}:
        check_ac_count(content, label, result)

    if doc_type == "plan":
        check_plan_phases(content, label, result)

    return result


def gather_targets(feature_dir: Path, check: str, design_file: str | None) -> List[Tuple[Path, str]]:
    targets: List[Tuple[Path, str]] = []

    if check in {"all", "prd"}:
        targets.append((feature_dir / "prd.md", "prd"))
    if check in {"all", "fdd"}:
        targets.append((feature_dir / "fdd.md", "fdd"))
    if check in {"all", "plan"}:
        targets.append((feature_dir / "plan.md", "plan"))

    if check in {"all", "design"}:
        if design_file:
            targets.append((Path(design_file), "design"))
        else:
            design_dir = feature_dir / "design"
            if design_dir.exists():
                for p in sorted(design_dir.glob("*.md")):
                    targets.append((p, "design"))
            elif check == "design":
                targets.append((design_dir / "<missing>.md", "design"))

    return targets


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate spec-pack markdown artifacts")
    parser.add_argument("feature_dir", help="Feature pack directory, e.g. docs/features/my-feature")
    parser.add_argument("--check", choices=["all", "prd", "fdd", "plan", "design"], default="all")
    parser.add_argument("--file", dest="design_file", help="Specific design file for --check design")
    parser.add_argument("--check-external-links", action="store_true", help="HTTP HEAD external links")
    parser.add_argument("--timeout", type=float, default=4.0, help="External link timeout seconds")
    args = parser.parse_args()

    feature_dir = Path(args.feature_dir)
    if not feature_dir.exists():
        print(f"ERROR: feature directory not found: {feature_dir}")
        return 1

    targets = gather_targets(feature_dir, args.check, args.design_file)
    if not targets:
        print("ERROR: no target files found for requested check")
        return 1

    all_errors: List[str] = []
    all_warnings: List[str] = []

    for file_path, doc_type in targets:
        res = validate_file(file_path, doc_type, args.check_external_links, args.timeout)
        all_errors.extend(res.errors)
        all_warnings.extend(res.warnings)

    if args.check == "all" and not any(t[1] == "design" for t in targets):
        print("WARN: no design/*.md files found; design validation skipped")

    if all_warnings:
        print("Warnings:")
        for w in all_warnings:
            print(f"- {w}")

    if all_errors:
        print("Validation failed:")
        for e in all_errors:
            print(f"- {e}")
        return 1

    print("Validation passed")
    for file_path, doc_type in targets:
        print(f"- {doc_type}: {file_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
