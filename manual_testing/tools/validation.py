from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import yaml

from manual_testing.tools.schema_contracts import (
    SchemaValidationError,
    load_schema,
    validate_against_schema,
)


SUPPORTED_TYPES = {"case", "suite", "run"}


def load_document(path: Path) -> Any:
    suffix = path.suffix.lower()
    if suffix in {".yml", ".yaml"}:
      return yaml.safe_load(path.read_text())
    if suffix == ".json":
      return json.loads(path.read_text())
    raise ValueError(f"Unsupported document type for {path}")


def infer_document_type(path: Path, document: Any) -> str:
    if path.suffix.lower() == ".json":
        return "run"

    if isinstance(document, dict):
        if "tests" in document:
            return "suite"
        if "steps" in document and "expected" in document:
            return "case"

    raise ValueError(f"Unable to infer document type for {path}")


def schema_name_for_doc_type(doc_type: str) -> str:
    mapping = {
        "case": "test_case",
        "suite": "test_suite",
        "run": "test_run",
    }
    if doc_type not in mapping:
        raise ValueError(f"Unsupported document type {doc_type!r}")
    return mapping[doc_type]


def validate_file(path: Path, doc_type: str | None = None) -> dict[str, Any]:
    document = load_document(path)
    resolved_type = doc_type or infer_document_type(path, document)
    validate_against_schema(document, load_schema(schema_name_for_doc_type(resolved_type)))
    return {
        "type": resolved_type,
        "document": document,
    }


def lint_file(path: Path, doc_type: str | None = None) -> list[str]:
    validated = validate_file(path, doc_type)
    resolved_type = validated["type"]
    document = validated["document"]

    if resolved_type == "case":
        return lint_case(document)
    if resolved_type == "suite":
        return lint_suite(path, document)
    if resolved_type == "run":
        return lint_run(document)
    return []


def lint_case(document: dict[str, Any]) -> list[str]:
    issues: list[str] = []
    issues.extend(_find_duplicate_ids(document.get("steps", []), "step"))
    issues.extend(_find_duplicate_ids(document.get("expected", []), "expected"))
    return issues


def lint_suite(path: Path, document: dict[str, Any]) -> list[str]:
    issues: list[str] = []
    tests = document.get("tests", [])
    if len(tests) != len(set(tests)):
        issues.append("suite contains duplicate test paths")

    for test_path in tests:
        resolved = (path.parent / test_path).resolve()
        if not resolved.exists():
            issues.append(f"suite test path does not exist: {test_path}")
    return issues


def lint_run(document: dict[str, Any]) -> list[str]:
    issues: list[str] = []
    issues.extend(_find_duplicate_key_ids(document.get("steps", []), "step_id", "step"))
    issues.extend(_find_duplicate_key_ids(document.get("assertions", []), "assertion_id", "assertion"))
    return issues


def _find_duplicate_ids(entries: list[dict[str, Any]], label: str) -> list[str]:
    return _find_duplicate_key_ids(entries, "id", label)


def _find_duplicate_key_ids(entries: list[dict[str, Any]], key: str, label: str) -> list[str]:
    seen: set[str] = set()
    issues: list[str] = []
    for entry in entries:
        value = entry.get(key)
        if value in seen:
            issues.append(f"duplicate {label} id: {value}")
        else:
            seen.add(value)
    return issues


def format_validation_error(error: Exception) -> str:
    if isinstance(error, SchemaValidationError):
        return str(error)
    return f"{error.__class__.__name__}: {error}"
