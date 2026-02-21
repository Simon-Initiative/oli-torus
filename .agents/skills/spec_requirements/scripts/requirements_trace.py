#!/usr/bin/env python3
"""Manage and validate requirements.yml traceability for Torus spec packs."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple

try:
    import yaml
except Exception as exc:  # noqa: BLE001
    print(f"ERROR: PyYAML is required: {exc}")
    sys.exit(1)


STATUS_ORDER = {
    "proposed": 0,
    "verified_fdd": 1,
    "verified_plan": 2,
    "verified": 3,
}
ALLOWED_STATUSES = set(STATUS_ORDER.keys())
ALLOWED_PROOF_TYPES = {"fdd", "plan", "test", "code", "manual"}
ALLOWED_VERIFICATION_METHODS = {"automated", "manual", "hybrid"}
AC_PATTERN = re.compile(r"\b(AC-\d{3})\b")
FR_PATTERN = re.compile(r"\b(FR-\d{3})\b")
ANNOTATION_PATTERN = re.compile(r'@ac\s+"(AC-\d{3})"')
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
TEST_NAME_RE = re.compile(r'test\s+"([^"]+)"')


def slugify_heading(text: str) -> str:
    lowered = text.strip().lower()
    lowered = re.sub(r"^\d+(?:\.\d+)*\s*", "", lowered)
    lowered = lowered.replace("*", "").replace("`", "")
    lowered = re.sub(r"[^a-z0-9\s-]", "", lowered)
    lowered = lowered.replace(" ", "-")
    return re.sub(r"-+", "-", lowered).strip("-")


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def load_yaml(path: Path) -> dict:
    if not path.exists():
        raise RuntimeError(f"file does not exist: {path}")
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        raise RuntimeError(f"{path}: expected a YAML mapping at root")
    return data


def dump_yaml(path: Path, data: dict) -> None:
    path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=False), encoding="utf-8")


def line_for_id(content: str, req_id: str) -> Optional[int]:
    for idx, line in enumerate(content.splitlines(), start=1):
        if req_id in line:
            return idx
    return None


def parse_prd_requirements(prd_content: str) -> List[dict]:
    requirements: List[dict] = []
    by_fr_id: Dict[str, dict] = {}
    current_fr_id: Optional[str] = None
    seen_fr: Set[str] = set()
    seen_ac: Set[str] = set()

    def get_or_create_fr(fr_id: str, title: Optional[str] = None) -> dict:
        existing = by_fr_id.get(fr_id)
        if existing is not None:
            if title and existing.get("title", "").endswith(" requirement"):
                existing["title"] = title
            return existing

        fr_obj = {
            "id": fr_id,
            "title": title or f"{fr_id} requirement",
            "status": "proposed",
            "acceptance_criteria": [],
        }
        by_fr_id[fr_id] = fr_obj
        requirements.append(fr_obj)
        return fr_obj

    def extract_fr_title(line: str, fr_id: str) -> str:
        if "|" in line:
            cells = [c.strip() for c in line.split("|")]
            # Markdown table row: | FR-001 | Description | Priority | Owner |
            if len(cells) >= 3 and cells[1] == fr_id and cells[2]:
                return cells[2]

        return (
            line.split(fr_id, 1)[1]
            .lstrip(":-. ")
            .strip()
            or f"{fr_id} requirement"
        )

    def extract_ac_title(line: str, ac_id: str) -> str:
        title = (
            line.split(ac_id, 1)[1]
            .lstrip(":-. ")
            .strip()
            or f"{ac_id} acceptance criterion"
        )
        # Strip leading "(FR-001, FR-002) — " linkage markers from AC lines.
        title = re.sub(
            r"^\((?:FR-\d{3}(?:\s*,\s*FR-\d{3})*)\)\s*(?:\u2014|-)?\s*",
            "",
            title,
        )
        return title or f"{ac_id} acceptance criterion"

    for raw_line in prd_content.splitlines():
        line = raw_line.strip()
        if not line:
            continue

        # AC lines often include FR IDs in parentheses. Parse ACs first.
        ac_match = re.search(r"\b(AC-\d{3})\b", line)
        if ac_match:
            ac_id = ac_match.group(1)
            if ac_id in seen_ac:
                continue

            linked_frs = FR_PATTERN.findall(line)
            target_fr_id = linked_frs[0] if linked_frs else current_fr_id
            if target_fr_id is None:
                continue

            fr_obj = get_or_create_fr(target_fr_id)
            fr_obj["acceptance_criteria"].append(
                {
                    "id": ac_id,
                    "title": extract_ac_title(line, ac_id),
                    "status": "proposed",
                    "verification_method": "automated",
                    "proofs": [],
                }
            )
            seen_ac.add(ac_id)
            continue

        fr_match = re.search(r"\b(FR-\d{3})\b", line)
        if fr_match:
            fr_id = fr_match.group(1)
            current_fr_id = fr_id
            if fr_id in seen_fr:
                continue
            get_or_create_fr(fr_id, extract_fr_title(line, fr_id))
            seen_fr.add(fr_id)

    return [fr for fr in requirements if fr["acceptance_criteria"]]


def _clean_id(raw: str) -> str:
    return re.sub(r"\s+", "", str(raw).strip().upper())


def _clean_title(raw: str) -> str:
    return re.sub(r"\s+", " ", str(raw).strip())


def normalize_requirements_payload(payload: object) -> List[dict]:
    if isinstance(payload, dict) and isinstance(payload.get("requirements"), list):
        source = payload["requirements"]
    elif isinstance(payload, list):
        source = payload
    else:
        raise RuntimeError("bulk payload must be a list of FR objects or an object with 'requirements'")

    normalized: List[dict] = []
    for fr in source:
        if not isinstance(fr, dict):
            raise RuntimeError("each FR in bulk payload must be an object")
        ac_in = fr.get("acceptance_criteria")
        if not isinstance(ac_in, list):
            raise RuntimeError("each FR in bulk payload must include acceptance_criteria list")

        normalized_fr = {
            "id": _clean_id(fr.get("id", "")),
            "title": _clean_title(fr.get("title", "")),
            "status": "proposed",
            "acceptance_criteria": [],
        }
        for ac in ac_in:
            if not isinstance(ac, dict):
                raise RuntimeError("each AC in bulk payload must be an object")
            normalized_fr["acceptance_criteria"].append(
                {
                    "id": _clean_id(ac.get("id", "")),
                    "title": _clean_title(ac.get("title", "")),
                    "status": "proposed",
                    "verification_method": _clean_title(ac.get("verification_method", "automated")).lower()
                    or "automated",
                    "proofs": [],
                }
            )
        normalized.append(normalized_fr)
    return normalized


def load_bulk_requirements(path: Path) -> List[dict]:
    if not path.exists():
        raise RuntimeError(f"bulk file does not exist: {path}")
    payload = yaml.safe_load(path.read_text(encoding="utf-8"))
    return normalize_requirements_payload(payload)


def build_empty_requirements_doc(feature_dir: Path) -> dict:
    return {
        "version": 1,
        "feature": feature_dir.name,
        "generated_from": "prd.md",
        "requirements": [],
    }


def validate_and_persist(feature_dir: Path, doc: dict) -> Tuple[bool, List[str], List[str]]:
    errors, warnings, changed = validate_structure(doc)
    if changed:
        save_requirements(feature_dir, doc)
    if errors:
        return False, errors, warnings
    save_requirements(feature_dir, doc)
    return True, [], warnings


def upsert_requirements(doc: dict, incoming: List[dict]) -> Tuple[int, int]:
    appended = 0
    edited = 0
    for fr_in in incoming:
        existing_fr = next((fr for fr in doc["requirements"] if fr["id"] == fr_in["id"]), None)
        if existing_fr is None:
            doc["requirements"].append(fr_in)
            appended += 1
            continue
        if existing_fr.get("title") != fr_in["title"]:
            existing_fr["title"] = fr_in["title"]
            edited += 1

        for ac_in in fr_in["acceptance_criteria"]:
            existing_ac = next(
                (ac for ac in existing_fr["acceptance_criteria"] if ac["id"] == ac_in["id"]),
                None,
            )
            if existing_ac is None:
                existing_fr["acceptance_criteria"].append(ac_in)
                appended += 1
            elif existing_ac.get("title") != ac_in["title"]:
                existing_ac["title"] = ac_in["title"]
                edited += 1
    return appended, edited


def remove_inline_requirements_from_prd(prd_path: Path) -> None:
    content = read_text(prd_path)
    lines = content.splitlines()
    sentence = "Requirements are found in requirements.yml"

    def headings_with_idx(current_lines: List[str]) -> List[Tuple[int, str]]:
        out: List[Tuple[int, str]] = []
        for i, line in enumerate(current_lines):
            m = re.match(r"^(#{1,6})\s+(.+?)\s*$", line)
            if m:
                out.append((i, m.group(2).strip().lower()))
        return out

    def replace_section_body(current_lines: List[str], key: str) -> bool:
        heading_idx = headings_with_idx(current_lines)
        match = next(((i, h) for i, h in heading_idx if key in h), None)
        if match is None:
            return False

        idx, _ = match
        next_heading = next((n for n, _h in heading_idx if n > idx), len(current_lines))
        # Replace full section body with the single pointer sentence.
        current_lines[idx + 1 : next_heading] = [sentence]
        return True

    touched = 0
    touched += 1 if replace_section_body(lines, "functional requirements") else 0
    touched += 1 if replace_section_body(lines, "acceptance criteria") else 0

    if touched < 2:
        if lines and lines[-1].strip():
            lines.append("")
        lines.extend(
            [
                "## Functional Requirements",
                sentence,
                "",
                "## Acceptance Criteria",
                sentence,
            ]
        )

    prd_path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def derive_fr_status(ac_list: Sequence[dict]) -> str:
    min_status = min(ac_list, key=lambda ac: STATUS_ORDER[ac["status"]])["status"]
    return min_status


def proof_types(ac: dict) -> Set[str]:
    return {proof["type"] for proof in ac.get("proofs", []) if isinstance(proof, dict)}


def validate_ac_status_from_proofs(ac: dict, errors: List[str]) -> None:
    status = ac["status"]
    method = ac.get("verification_method", "automated")
    ptypes = proof_types(ac)

    if status == "proposed":
        return

    if "fdd" not in ptypes:
        errors.append(f"{ac['id']}: status {status} requires at least one fdd proof")

    if status in {"verified_plan", "verified"} and "plan" not in ptypes:
        errors.append(f"{ac['id']}: status {status} requires at least one plan proof")

    if status == "verified":
        if method == "automated" and "test" not in ptypes:
            errors.append(f"{ac['id']}: automated verified status requires at least one test proof")
        if method == "manual" and "manual" not in ptypes:
            errors.append(f"{ac['id']}: manual verified status requires at least one manual proof")
        if method == "hybrid" and not {"test", "manual"}.issubset(ptypes):
            errors.append(f"{ac['id']}: hybrid verified status requires both test and manual proofs")


def expected_status_from_proofs(ac: dict) -> str:
    ptypes = proof_types(ac)
    method = ac.get("verification_method", "automated")

    base = "proposed"
    if "fdd" in ptypes:
        base = "verified_fdd"
    if {"fdd", "plan"}.issubset(ptypes):
        base = "verified_plan"

    verified_ok = False
    if method == "automated":
        verified_ok = {"fdd", "plan", "test"}.issubset(ptypes)
    elif method == "manual":
        verified_ok = {"fdd", "plan", "manual"}.issubset(ptypes)
    elif method == "hybrid":
        verified_ok = {"fdd", "plan", "test", "manual"}.issubset(ptypes)

    if verified_ok:
        return "verified"
    return base


def validate_structure(data: dict) -> Tuple[List[str], List[str], bool]:
    errors: List[str] = []
    warnings: List[str] = []
    changed = False

    if data.get("version") != 1:
        errors.append("version must equal 1")
    if not isinstance(data.get("feature"), str) or not data["feature"].strip():
        errors.append("feature must be a non-empty string")
    if not isinstance(data.get("generated_from"), str) or not data["generated_from"].strip():
        errors.append("generated_from must be a non-empty string")

    requirements = data.get("requirements")
    if not isinstance(requirements, list) or not requirements:
        errors.append("requirements must be a non-empty list")
        return errors, warnings, changed

    all_ids: Set[str] = set()
    fr_ids: Set[str] = set()
    ac_ids: Set[str] = set()

    for fr in requirements:
        if not isinstance(fr, dict):
            errors.append("each requirements item must be an object")
            continue
        fr_id = fr.get("id")
        if not isinstance(fr_id, str) or not re.fullmatch(r"FR-\d{3}", fr_id):
            errors.append(f"invalid FR id: {fr_id}")
            continue
        if fr_id in all_ids:
            errors.append(f"duplicate id: {fr_id}")
        all_ids.add(fr_id)
        fr_ids.add(fr_id)

        if "proofs" in fr:
            errors.append(f"{fr_id}: proofs are not allowed at FR level")
        if not isinstance(fr.get("title"), str) or not fr["title"].strip():
            errors.append(f"{fr_id}: title must be non-empty")
        if fr.get("status") not in ALLOWED_STATUSES:
            errors.append(f"{fr_id}: invalid status {fr.get('status')}")

        ac_list = fr.get("acceptance_criteria")
        if not isinstance(ac_list, list) or not ac_list:
            errors.append(f"{fr_id}: acceptance_criteria must be a non-empty list")
            continue

        for ac in ac_list:
            if not isinstance(ac, dict):
                errors.append(f"{fr_id}: each AC must be an object")
                continue
            ac_id = ac.get("id")
            if not isinstance(ac_id, str) or not re.fullmatch(r"AC-\d{3}", ac_id):
                errors.append(f"{fr_id}: invalid AC id: {ac_id}")
                continue
            if ac_id in all_ids:
                errors.append(f"duplicate id: {ac_id}")
            all_ids.add(ac_id)
            ac_ids.add(ac_id)

            if not isinstance(ac.get("title"), str) or not ac["title"].strip():
                errors.append(f"{ac_id}: title must be non-empty")
            if ac.get("status") not in ALLOWED_STATUSES:
                errors.append(f"{ac_id}: invalid status {ac.get('status')}")

            method = ac.get("verification_method", "automated")
            if method not in ALLOWED_VERIFICATION_METHODS:
                errors.append(f"{ac_id}: invalid verification_method {method}")
            if "verification_method" not in ac:
                ac["verification_method"] = "automated"
                changed = True

            proofs = ac.get("proofs")
            if not isinstance(proofs, list):
                errors.append(f"{ac_id}: proofs must be a list")
                continue

            seen_proofs: Set[Tuple[str, str]] = set()
            for proof in proofs:
                if not isinstance(proof, dict):
                    errors.append(f"{ac_id}: each proof must be an object")
                    continue
                ptype = proof.get("type")
                pref = proof.get("ref")
                if ptype not in ALLOWED_PROOF_TYPES:
                    errors.append(f"{ac_id}: invalid proof type {ptype}")
                if not isinstance(pref, str) or not pref.strip():
                    errors.append(f"{ac_id}: proof ref must be non-empty")
                key = (str(ptype), str(pref))
                if key in seen_proofs:
                    errors.append(f"{ac_id}: duplicate proof {ptype}:{pref}")
                seen_proofs.add(key)

            validate_ac_status_from_proofs(ac, errors)

        expected_fr_status = derive_fr_status(ac_list)
        if fr.get("status") != expected_fr_status:
            warnings.append(f"{fr_id}: status corrected to derived value {expected_fr_status}")
            fr["status"] = expected_fr_status
            changed = True

    if fr_ids.intersection(ac_ids):
        errors.append("FR and AC IDs must not overlap")

    return errors, warnings, changed


def add_proof(ac: dict, ptype: str, ref: str) -> bool:
    proofs = ac.setdefault("proofs", [])
    candidate = {"type": ptype, "ref": ref}
    if candidate in proofs:
        return False
    proofs.append(candidate)
    return True


def promote_status(ac: dict, target_status: str) -> bool:
    current = ac["status"]
    if STATUS_ORDER[target_status] > STATUS_ORDER[current]:
        ac["status"] = target_status
        return True
    return False


def find_id_lines(content: str, ids: Iterable[str]) -> Dict[str, int]:
    remaining = set(ids)
    found: Dict[str, int] = {}
    for idx, line in enumerate(content.splitlines(), start=1):
        for req_id in list(remaining):
            if req_id in line:
                found[req_id] = idx
                remaining.remove(req_id)
    return found


def requirements_file(feature_dir: Path) -> Path:
    return feature_dir / "requirements.yml"


def load_requirements(feature_dir: Path) -> dict:
    return load_yaml(requirements_file(feature_dir))


def save_requirements(feature_dir: Path, data: dict) -> None:
    dump_yaml(requirements_file(feature_dir), data)


def action_init_from_prd(feature_dir: Path) -> int:
    prd = feature_dir / "prd.md"
    req_path = requirements_file(feature_dir)
    if not prd.exists():
        print(f"ERROR: missing PRD: {prd}")
        return 1
    if req_path.exists():
        print(f"ERROR: init_from_prd cannot run because requirements.yml already exists: {req_path}")
        return 1

    requirements = parse_prd_requirements(read_text(prd))
    if not requirements:
        print("ERROR: no FR/AC IDs found in prd.md")
        return 1

    doc = {
        "version": 1,
        "feature": feature_dir.name,
        "generated_from": "prd.md",
        "requirements": requirements,
    }
    ok, errors, warnings = validate_and_persist(feature_dir, doc)
    for w in warnings:
        print(f"WARN: {w}")
    if not ok:
        print("init_from_prd failed:")
        for e in errors:
            print(f"- {e}")
        return 1

    remove_inline_requirements_from_prd(prd)
    print(
        f"Initialized {requirements_file(feature_dir)} with {len(requirements)} FR(s) "
        "and removed inline FR/AC blocks from prd.md"
    )
    return 0


def action_capture(feature_dir: Path, bulk_file: Optional[str]) -> int:
    prd = feature_dir / "prd.md"
    extracted: List[dict]
    if bulk_file:
        bulk_path = Path(bulk_file)
        if not bulk_path.is_absolute():
            bulk_path = (feature_dir / bulk_file).resolve()
        try:
            extracted = load_bulk_requirements(bulk_path)
        except Exception as exc:  # noqa: BLE001
            print(f"ERROR: failed loading bulk requirements: {exc}")
            return 1
    else:
        if not prd.exists():
            print(f"ERROR: missing PRD: {prd}")
            return 1
        extracted = parse_prd_requirements(read_text(prd))
        if not extracted:
            print("ERROR: no FR/AC IDs found in prd.md")
            return 1

    req_path = requirements_file(feature_dir)
    if req_path.exists():
        doc = load_requirements(feature_dir)
    else:
        doc = build_empty_requirements_doc(feature_dir)

    appended, edited = upsert_requirements(doc, extracted)
    ok, errors, warnings = validate_and_persist(feature_dir, doc)
    for w in warnings:
        print(f"WARN: {w}")
    if not ok:
        print("capture failed:")
        for e in errors:
            print(f"- {e}")
        return 1

    print(
        f"capture completed: appended={appended}, edited={edited}, warnings={len(warnings)}"
    )
    return 0


def get_all_ids(doc: dict) -> Tuple[List[str], List[str]]:
    fr_ids: List[str] = []
    ac_ids: List[str] = []
    for fr in doc.get("requirements", []):
        fr_ids.append(fr["id"])
        for ac in fr.get("acceptance_criteria", []):
            ac_ids.append(ac["id"])
    return fr_ids, ac_ids


def action_validate_structure(feature_dir: Path) -> int:
    doc = load_requirements(feature_dir)
    errors, warnings, changed = validate_structure(doc)
    if changed:
        save_requirements(feature_dir, doc)
    for w in warnings:
        print(f"WARN: {w}")
    if errors:
        print("Validation failed:")
        for e in errors:
            print(f"- {e}")
        return 1
    print("Structure validation passed")
    return 0


def action_verify_fdd(feature_dir: Path) -> int:
    doc = load_requirements(feature_dir)
    errors, warnings, changed = validate_structure(doc)
    fdd = feature_dir / "fdd.md"
    if not fdd.exists():
        errors.append(f"missing FDD: {fdd}")
    else:
        content = read_text(fdd)
        fr_ids, ac_ids = get_all_ids(doc)
        found = find_id_lines(content, fr_ids + ac_ids)

        for fr in doc["requirements"]:
            if fr["id"] not in found:
                errors.append(f"{fr['id']}: not explicitly referenced in fdd.md")
            for ac in fr["acceptance_criteria"]:
                line = found.get(ac["id"])
                if line is None:
                    errors.append(f"{ac['id']}: not explicitly referenced in fdd.md")
                    continue
                changed = add_proof(ac, "fdd", f"fdd.md:{line}") or changed
                changed = promote_status(ac, "verified_fdd") or changed
            expected = derive_fr_status(fr["acceptance_criteria"])
            if fr["status"] != expected:
                fr["status"] = expected
                changed = True

    if changed:
        save_requirements(feature_dir, doc)
    for w in warnings:
        print(f"WARN: {w}")
    if errors:
        print("verify_fdd failed:")
        for e in errors:
            print(f"- {e}")
        return 1
    print("verify_fdd completed")
    return 0


def action_verify_plan(feature_dir: Path) -> int:
    doc = load_requirements(feature_dir)
    errors, warnings, changed = validate_structure(doc)
    plan = feature_dir / "plan.md"
    if not plan.exists():
        errors.append(f"missing PLAN: {plan}")
    else:
        content = read_text(plan)
        _, ac_ids = get_all_ids(doc)
        found = find_id_lines(content, ac_ids)

        for fr in doc["requirements"]:
            for ac in fr["acceptance_criteria"]:
                line = found.get(ac["id"])
                if line is None:
                    errors.append(f"{ac['id']}: not explicitly referenced in plan.md")
                    continue
                changed = add_proof(ac, "plan", f"plan.md:{line}") or changed
                if "fdd" in proof_types(ac):
                    changed = promote_status(ac, "verified_plan") or changed
            expected = derive_fr_status(fr["acceptance_criteria"])
            if fr["status"] != expected:
                fr["status"] = expected
                changed = True

    if changed:
        save_requirements(feature_dir, doc)
    for w in warnings:
        print(f"WARN: {w}")
    if errors:
        print("verify_plan failed:")
        for e in errors:
            print(f"- {e}")
        return 1
    print("verify_plan completed")
    return 0


def gather_test_annotations(repo_root: Path) -> Dict[str, List[Tuple[str, int, str]]]:
    mapping: Dict[str, List[Tuple[str, int, str]]] = {}
    test_dir = repo_root / "test"
    if not test_dir.exists():
        return mapping

    for test_file in sorted(test_dir.rglob("*.exs")):
        rel = test_file.relative_to(repo_root).as_posix()
        lines = read_text(test_file).splitlines()
        for i, line in enumerate(lines):
            ann = ANNOTATION_PATTERN.search(line)
            if not ann:
                continue
            ac_id = ann.group(1)
            test_name = ""
            for lookahead in lines[i : min(i + 8, len(lines))]:
                test_match = TEST_NAME_RE.search(lookahead)
                if test_match:
                    test_name = test_match.group(1)
                    break
            mapping.setdefault(ac_id, []).append((rel, i + 1, test_name))
    return mapping


def find_repo_root(start: Path) -> Path:
    current = start.resolve()
    for candidate in [current, *current.parents]:
        if (candidate / ".agents").exists():
            return candidate
    return current


def action_verify_implementation(feature_dir: Path) -> int:
    repo_root = find_repo_root(feature_dir)
    doc = load_requirements(feature_dir)
    errors, warnings, changed = validate_structure(doc)
    annotations = gather_test_annotations(repo_root)

    known_acs: Set[str] = set()
    for fr in doc["requirements"]:
        for ac in fr["acceptance_criteria"]:
            known_acs.add(ac["id"])
            matches = annotations.get(ac["id"], [])
            for rel, line, test_name in matches:
                ref = f'{rel}::"{test_name}"' if test_name else f"{rel}:{line}"
                changed = add_proof(ac, "test", ref) or changed
            expected = expected_status_from_proofs(ac)
            if expected == "verified":
                changed = promote_status(ac, "verified") or changed
        expected_fr = derive_fr_status(fr["acceptance_criteria"])
        if fr["status"] != expected_fr:
            fr["status"] = expected_fr
            changed = True

    unknown = sorted(set(annotations.keys()) - known_acs)
    for ac_id in unknown:
        errors.append(f"unknown AC annotation found in tests: {ac_id}")

    if changed:
        save_requirements(feature_dir, doc)
    for w in warnings:
        print(f"WARN: {w}")
    if errors:
        print("verify_implementation failed:")
        for e in errors:
            print(f"- {e}")
        return 1
    print("verify_implementation completed")
    return 0


def resolve_ref(feature_dir: Path, repo_root: Path, ref: str) -> Tuple[Path, Optional[str], Optional[int], Optional[str]]:
    # Returns (path, anchor, line, descriptor)
    descriptor = None
    anchor = None
    line = None
    path_part = ref

    if "::" in ref:
        path_part, descriptor = ref.split("::", 1)
        descriptor = descriptor.strip()
    elif re.search(r":\d+$", ref):
        path_part, line_txt = ref.rsplit(":", 1)
        line = int(line_txt)
    elif "#" in ref:
        path_part, anchor = ref.split("#", 1)
        anchor = anchor.strip()

    feature_relative = (feature_dir / path_part).resolve()
    repo_relative = (repo_root / path_part).resolve()
    path = feature_relative if feature_relative.exists() else repo_relative
    return path, anchor, line, descriptor


def validate_anchor(path: Path, anchor: str) -> bool:
    content = read_text(path)
    anchors = {slugify_heading(m.group(2)) for m in HEADING_RE.finditer(content)}
    return anchor.lower() in anchors


def validate_manual_section(path: Path, anchor: str) -> bool:
    content = read_text(path)
    if not validate_anchor(path, anchor):
        return False

    lines = content.splitlines()
    section_lines: List[str] = []
    capture = False
    anchor_slug = anchor.lower()
    for line in lines:
        head_match = re.match(r"^(#{1,6})\s+(.+?)\s*$", line)
        if head_match:
            slug = slugify_heading(head_match.group(2))
            if slug == anchor_slug:
                capture = True
                section_lines = []
                continue
            if capture:
                break
        if capture:
            section_lines.append(line.lower())

    text = "\n".join(section_lines)
    return all(keyword in text for keyword in ("preconditions", "steps", "expected outcome"))


def action_master_validate(feature_dir: Path, stage: str) -> int:
    doc = load_requirements(feature_dir)
    errors, warnings, changed = validate_structure(doc)
    repo_root = find_repo_root(feature_dir)

    ac_ids: Set[str] = set()
    for fr in doc.get("requirements", []):
        for ac in fr.get("acceptance_criteria", []):
            ac_id = ac["id"]
            ac_ids.add(ac_id)
            for proof in ac.get("proofs", []):
                path, anchor, line, _descriptor = resolve_ref(feature_dir, repo_root, proof["ref"])
                if not path.exists():
                    errors.append(f"{ac_id}: proof path does not exist: {proof['ref']}")
                    continue
                if anchor and not validate_anchor(path, anchor):
                    errors.append(f"{ac_id}: proof anchor not found: {proof['ref']}")
                if line is not None:
                    line_count = len(read_text(path).splitlines())
                    if line < 1 or line > line_count:
                        errors.append(f"{ac_id}: proof line out of bounds: {proof['ref']}")
                if proof["type"] in {"fdd", "plan"} and ac_id not in read_text(path):
                    errors.append(f"{ac_id}: {proof['type']} proof file does not reference AC ID: {proof['ref']}")
                if proof["type"] == "test":
                    content = read_text(path)
                    if f'@ac "{ac_id}"' not in content:
                        errors.append(f"{ac_id}: test proof missing required annotation: {proof['ref']}")
                if proof["type"] == "manual":
                    if not anchor:
                        errors.append(f"{ac_id}: manual proof must include an anchor: {proof['ref']}")
                    elif not validate_manual_section(path, anchor):
                        errors.append(f"{ac_id}: manual proof section missing required structure: {proof['ref']}")

            expected = expected_status_from_proofs(ac)
            if STATUS_ORDER[ac["status"]] < STATUS_ORDER[expected]:
                errors.append(f"{ac_id}: status {ac['status']} is below proof-backed minimum {expected}")

        expected_fr = derive_fr_status(fr["acceptance_criteria"])
        if fr["status"] != expected_fr:
            fr["status"] = expected_fr
            changed = True

    annotations = gather_test_annotations(repo_root)
    unknown = sorted(set(annotations.keys()) - ac_ids)
    for ac_id in unknown:
        errors.append(f"unknown AC ID in test annotations: {ac_id}")

    required_level = {
        "fdd_only": "verified_fdd",
        "plan_present": "verified_plan",
        "implementation_complete": "verified",
    }[stage]

    for fr in doc.get("requirements", []):
        for ac in fr.get("acceptance_criteria", []):
            if STATUS_ORDER[ac["status"]] < STATUS_ORDER[required_level]:
                errors.append(f"{ac['id']}: status {ac['status']} below stage requirement {required_level}")

    if changed:
        save_requirements(feature_dir, doc)
    for w in warnings:
        print(f"WARN: {w}")
    if errors:
        print("master_validate failed:")
        for e in errors:
            print(f"- {e}")
        return 1

    print(f"master_validate passed ({stage})")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Manage requirements.yml traceability")
    parser.add_argument("feature_dir", help="Feature dir, e.g. docs/features/my-feature")
    parser.add_argument(
        "--action",
        required=True,
        choices=[
            "init_from_prd",
            "capture",
            "validate_structure",
            "verify_fdd",
            "verify_plan",
            "verify_implementation",
            "master_validate",
        ],
    )
    parser.add_argument(
        "--stage",
        choices=["fdd_only", "plan_present", "implementation_complete"],
        help="Required with --action master_validate",
    )
    parser.add_argument(
        "--bulk-file",
        help="Optional YAML file for --action capture with either 'requirements: [...]' or a top-level FR list",
    )
    args = parser.parse_args()

    feature_dir = Path(args.feature_dir)
    if not feature_dir.exists():
        print(f"ERROR: feature directory not found: {feature_dir}")
        return 1

    if args.action == "master_validate" and not args.stage:
        print("ERROR: --stage is required for --action master_validate")
        return 1
    if args.action != "master_validate" and args.stage:
        print("ERROR: --stage is only valid with --action master_validate")
        return 1
    if args.action != "capture" and args.bulk_file:
        print("ERROR: --bulk-file is only valid with --action capture")
        return 1

    if args.action == "init_from_prd":
        return action_init_from_prd(feature_dir)
    if args.action == "capture":
        return action_capture(feature_dir, args.bulk_file)
    if args.action == "validate_structure":
        return action_validate_structure(feature_dir)
    if args.action == "verify_fdd":
        return action_verify_fdd(feature_dir)
    if args.action == "verify_plan":
        return action_verify_plan(feature_dir)
    if args.action == "verify_implementation":
        return action_verify_implementation(feature_dir)
    if args.action == "master_validate":
        return action_master_validate(feature_dir, args.stage)
    return 1


if __name__ == "__main__":
    sys.exit(main())
