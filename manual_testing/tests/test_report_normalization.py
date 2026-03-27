from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from manual_testing.tools.reporting import (
    normalize_runtime_result,
    write_run_report,
    write_suite_summary,
)
from manual_testing.tools.runtime_contract import build_execution_requests


ROOT = Path(__file__).resolve().parents[1]


class ReportNormalizationTests(unittest.TestCase):
    def test_normalize_runtime_result_assigns_blocked_failure_kind(self) -> None:
        manifest = build_execution_requests(
            manual_testing_root=ROOT,
            target_type="case",
            target_id="delivery_smoke",
            environment_label="staging",
            credentials_source_ref="staging-shared-qa",
            doc_context_paths=[],
            base_url="https://staging.example.org",
            run_label="20260326t153000z",
        )[0]
        runtime_result = json.loads((ROOT / "tests/fixtures/runtime_result_blocked.json").read_text())

        report = normalize_runtime_result(manifest, runtime_result)

        self.assertEqual(report["failure_kind"], "blocked")
        self.assertEqual(report["suite_id"] if "suite_id" in report else None, None)
        self.assertEqual(report["case_path"], manifest["test_case_path"])

    def test_normalize_runtime_result_assigns_error_failure_kind(self) -> None:
        manifest = build_execution_requests(
            manual_testing_root=ROOT,
            target_type="case",
            target_id="authoring_smoke",
            environment_label="dev",
            credentials_source_ref="dev-authoring-smoke",
            doc_context_paths=[],
            run_label="20260326t153000z",
        )[0]
        runtime_result = json.loads((ROOT / "tests/fixtures/runtime_result_error.json").read_text())

        report = normalize_runtime_result(manifest, runtime_result)

        self.assertEqual(report["failure_kind"], "execution_error")
        self.assertEqual(report["status"], "error")

    def test_write_run_report_and_suite_summary(self) -> None:
        manifest = build_execution_requests(
            manual_testing_root=ROOT,
            target_type="suite",
            target_id="smoke",
            environment_label="staging",
            credentials_source_ref="staging-shared-qa",
            doc_context_paths=[],
            base_url="https://staging.example.org",
            run_label="20260326t153000z",
        )[0]
        runtime_result = json.loads((ROOT / "tests/fixtures/runtime_result_blocked.json").read_text())
        report = normalize_runtime_result(manifest, runtime_result)

        with tempfile.TemporaryDirectory() as temp_dir:
            results_root = Path(temp_dir)
            report_path = write_run_report(report, results_root)
            summary_path = write_suite_summary(
                suite_id=report["suite_id"],
                suite_run_id=manifest["suite_run_id"],
                reports=[report],
                results_root=results_root,
            )

            self.assertTrue(report_path.exists())
            self.assertTrue(summary_path.exists())
            summary = json.loads(summary_path.read_text())
            self.assertEqual(summary["status_counts"]["blocked"], 1)
            self.assertEqual(summary["suite_run_id"], "smoke-20260326t153000z")


if __name__ == "__main__":
    unittest.main()
