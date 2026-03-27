from __future__ import annotations

import csv
from collections import OrderedDict
from pathlib import Path
from typing import Any

import yaml


def convert_csv_to_cases(input_path: Path, output_dir: Path) -> list[dict[str, Any]]:
    with input_path.open(newline="") as input_file:
        rows = list(csv.DictReader(input_file))
    grouped: "OrderedDict[str, list[dict[str, str]]]" = OrderedDict()
    for row in rows:
        test_id = (row.get("test_id") or "").strip()
        if not test_id:
            raise ValueError("CSV row is missing required test_id")
        grouped.setdefault(test_id, []).append(row)

    outputs = []
    output_dir.mkdir(parents=True, exist_ok=True)

    for test_id, grouped_rows in grouped.items():
        case_doc, warnings = _build_case_doc(test_id, grouped_rows, input_path)
        output_path = output_dir / f"{test_id}.yml"
        output_path.write_text(yaml.safe_dump(case_doc, sort_keys=False))
        outputs.append(
            {
                "test_id": test_id,
                "output_path": str(output_path),
                "warnings": warnings,
            }
        )

    return outputs


def _build_case_doc(test_id: str, rows: list[dict[str, str]], input_path: Path) -> tuple[dict[str, Any], list[str]]:
    warnings: list[str] = []
    metadata = {
        "title": _stable_scalar(rows, "title", warnings),
        "description": _stable_scalar(rows, "description", warnings, optional=True),
        "domain": _stable_scalar(rows, "domain", warnings, optional=True),
    }

    tags = _split_multi_value(_stable_scalar(rows, "tags", warnings, optional=True))
    preconditions = _split_multiline_values(rows, "preconditions")
    notes = _split_multiline_values(rows, "notes")

    steps = []
    expected = []
    for row_index, row in enumerate(rows, start=2):
        step_id = (row.get("step_id") or "").strip()
        step_instruction = (row.get("step_instruction") or "").strip()
        expected_id = (row.get("expected_id") or "").strip()
        expected_description = (row.get("expected_description") or "").strip()

        if not step_id and step_instruction:
            warning = f"row {row_index}: step_instruction present without step_id"
            warnings.append(warning)
            step_id = f"step_{len(steps) + 1}"
        if step_id and not step_instruction:
            warnings.append(f"row {row_index}: step_id {step_id!r} present without step_instruction")
        if step_id and step_instruction:
            steps.append({"id": step_id, "instruction": step_instruction})

        if not expected_id and expected_description:
            warning = f"row {row_index}: expected_description present without expected_id"
            warnings.append(warning)
            expected_id = f"expected_{len(expected) + 1}"
        if expected_id and not expected_description:
            warnings.append(f"row {row_index}: expected_id {expected_id!r} present without expected_description")
        if expected_id and expected_description:
            expected.append({"id": expected_id, "description": expected_description})

        if not step_id and not step_instruction and not expected_id and not expected_description:
            warnings.append(f"row {row_index}: no step or expected fields were present")

    case_doc: dict[str, Any] = {
        "id": test_id,
        "title": metadata["title"] or test_id,
        "steps": steps,
        "expected": expected,
        "source": {
            "origin": "csv",
            "reference": str(input_path),
        },
    }

    if metadata["description"]:
        case_doc["description"] = metadata["description"]
    if metadata["domain"]:
        case_doc["domain"] = metadata["domain"]
    if tags:
        case_doc["tags"] = tags
    if preconditions:
        case_doc["preconditions"] = preconditions
    if notes:
        case_doc["notes"] = notes
    if warnings:
        case_doc["source"]["warnings"] = warnings

    return case_doc, warnings


def _stable_scalar(
    rows: list[dict[str, str]],
    key: str,
    warnings: list[str],
    optional: bool = False,
) -> str | None:
    values = [value.strip() for value in (row.get(key, "") for row in rows) if value.strip()]
    if not values:
        if optional:
            return None
        raise ValueError(f"CSV rows are missing required {key}")
    first = values[0]
    if any(value != first for value in values[1:]):
        warnings.append(f"inconsistent {key} values detected; using first non-empty value")
    return first


def _split_multi_value(value: str | None) -> list[str]:
    if not value:
        return []
    return [item.strip() for item in value.split("|") if item.strip()]


def _split_multiline_values(rows: list[dict[str, str]], key: str) -> list[str]:
    items: list[str] = []
    for row in rows:
        value = (row.get(key) or "").strip()
        if not value:
            continue
        for part in value.split("||"):
            normalized = part.strip()
            if normalized:
                items.append(normalized)
    deduped: list[str] = []
    for item in items:
        if item not in deduped:
            deduped.append(item)
    return deduped
