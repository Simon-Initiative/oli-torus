from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from manual_testing.tools.schema_contracts import load_schema, validate_against_schema


def normalize_runtime_result(
    manifest: dict[str, Any],
    runtime_result: dict[str, Any],
) -> dict[str, Any]:
    status = runtime_result["status"]
    report = {
        "run_id": manifest["run_id"],
        "test_id": manifest["case_id"],
        "status": status,
        "started_at": runtime_result["started_at"],
        "completed_at": runtime_result["completed_at"],
        "duration_seconds": runtime_result["duration_seconds"],
        "steps": runtime_result["steps"],
        "assertions": runtime_result["assertions"],
        "agent_notes": runtime_result.get("agent_notes", []),
        "confidence": runtime_result["confidence"],
        "case_path": manifest["test_case_path"],
        "upload": {"status": "pending"},
    }

    if "base_url" in manifest:
        report["base_url"] = manifest["base_url"]
    if "suite_id" in manifest:
        report["suite_id"] = manifest["suite_id"]
    if "artifacts" in runtime_result:
        report["artifacts"] = runtime_result["artifacts"]

    failure_kind = runtime_result.get("failure_kind") or _default_failure_kind(status)
    if failure_kind is not None:
        report["failure_kind"] = failure_kind

    validate_against_schema(report, load_schema("test_run"))
    return report


def write_run_report(report: dict[str, Any], results_root: Path) -> Path:
    run_dir = results_root / report["run_id"]
    run_dir.mkdir(parents=True, exist_ok=True)
    report_path = run_dir / "report.json"
    report_path.write_text(json.dumps(report, indent=2))
    return report_path


def write_suite_summary(
    *,
    suite_id: str,
    suite_run_id: str,
    reports: list[dict[str, Any]],
    results_root: Path,
) -> Path:
    suite_dir = results_root / f"{suite_run_id}-summary"
    suite_dir.mkdir(parents=True, exist_ok=True)
    summary = {
        "suite_id": suite_id,
        "suite_run_id": suite_run_id,
        "total_reports": len(reports),
        "status_counts": _count_statuses(reports),
        "run_ids": [report["run_id"] for report in reports],
    }
    summary_path = suite_dir / "summary.json"
    summary_path.write_text(json.dumps(summary, indent=2))
    return summary_path


def _default_failure_kind(status: str) -> str | None:
    defaults = {
        "failed": "assertion_failed",
        "blocked": "blocked",
        "error": "execution_error",
    }
    return defaults.get(status)


def _count_statuses(reports: list[dict[str, Any]]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for report in reports:
        counts[report["status"]] = counts.get(report["status"], 0) + 1
    return counts
