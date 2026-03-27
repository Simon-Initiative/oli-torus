from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml


def build_execution_requests(
    *,
    manual_testing_root: Path,
    target_type: str,
    target_id: str,
    environment_label: str,
    credentials_source_ref: str,
    doc_context_paths: list[str],
    base_url: str | None = None,
    release_ref: str | None = None,
    run_label: str | None = None,
) -> list[dict[str, Any]]:
    resolved_cases, suite_id = _resolve_target(manual_testing_root, target_type, target_id)
    resolved_run_label = run_label or _default_run_label()
    suite_run_id = f"{suite_id}-{resolved_run_label}" if suite_id else None

    requests = []
    for index, case_path in enumerate(resolved_cases, start=1):
        case_doc = yaml.safe_load(case_path.read_text())
        run_id = f"{suite_run_id}-{index:03d}" if suite_run_id else f"{case_doc['id']}-{resolved_run_label}"
        request = {
            "run_id": run_id,
            "test_case_path": _relative_to_root(case_path, manual_testing_root.parent),
            "case_id": case_doc["id"],
            "environment_label": environment_label,
            "credentials_source_ref": credentials_source_ref,
            "doc_context_paths": doc_context_paths,
            "artifact_dir": f"manual_testing/results/{run_id}/artifacts",
        }
        if base_url:
            request["base_url"] = base_url
        if suite_id:
            request["suite_id"] = suite_id
            request["suite_run_id"] = suite_run_id
        if release_ref:
            request["release_ref"] = release_ref
        if run_label:
            request["run_label"] = run_label
        requests.append(request)

    return requests


def _resolve_target(manual_testing_root: Path, target_type: str, target_id: str) -> tuple[list[Path], str | None]:
    if target_type == "case":
        case_path = _find_case_path(manual_testing_root, target_id)
        return [case_path], None
    if target_type == "suite":
        suite_path = manual_testing_root / "suites" / f"{target_id}.yml"
        if not suite_path.exists():
            raise ValueError(f"Unknown suite id: {target_id}")
        suite_doc = yaml.safe_load(suite_path.read_text())
        case_paths = [(suite_path.parent / test_path).resolve() for test_path in suite_doc["tests"]]
        return case_paths, suite_doc["id"]
    raise ValueError(f"Unsupported target_type: {target_type}")


def _find_case_path(manual_testing_root: Path, case_id: str) -> Path:
    for path in (manual_testing_root / "cases").rglob("*.yml"):
        case_doc = yaml.safe_load(path.read_text())
        if case_doc.get("id") == case_id:
            return path
    raise ValueError(f"Unknown case id: {case_id}")


def _relative_to_root(path: Path, repo_root: Path) -> str:
    return str(path.relative_to(repo_root))


def _default_run_label() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dt%H%M%Sz").lower()
