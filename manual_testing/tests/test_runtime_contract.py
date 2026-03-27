from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from manual_testing.tools.runtime_contract import build_execution_requests


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "tools/manualtest.py"


class RuntimeContractTests(unittest.TestCase):
    def test_build_execution_requests_for_suite_expands_each_case(self) -> None:
        requests = build_execution_requests(
            manual_testing_root=ROOT,
            target_type="suite",
            target_id="smoke",
            environment_label="staging",
            credentials_source_ref="staging-shared-qa",
            doc_context_paths=["docs/exec-plans/current/epics/automated_testing/experiment/prd.md"],
            base_url="https://staging.example.org",
            release_ref="v0.34.0",
            run_label="20260326t153000z",
        )

        self.assertEqual(len(requests), 2)
        self.assertEqual(requests[0]["suite_id"], "smoke")
        self.assertEqual(requests[0]["suite_run_id"], "smoke-20260326t153000z")
        self.assertEqual(requests[0]["environment_label"], "staging")
        self.assertEqual(requests[0]["release_ref"], "v0.34.0")
        self.assertTrue(requests[0]["run_id"].startswith("smoke-20260326t153000z-"))
        self.assertTrue(requests[0]["artifact_dir"].startswith("manual_testing/results/"))

    def test_build_execution_requests_for_case_resolves_single_case(self) -> None:
        requests = build_execution_requests(
            manual_testing_root=ROOT,
            target_type="case",
            target_id="authoring_smoke",
            environment_label="dev",
            credentials_source_ref="dev-authoring-smoke",
            doc_context_paths=[],
            run_label="20260326t153000z",
        )

        self.assertEqual(len(requests), 1)
        self.assertEqual(requests[0]["case_id"], "authoring_smoke")
        self.assertNotIn("suite_id", requests[0])
        self.assertEqual(requests[0]["run_id"], "authoring_smoke-20260326t153000z")

    def test_prepare_run_cli_outputs_json_requests(self) -> None:
        result = subprocess.run(
            [
                "python3",
                str(CLI),
                "prepare-run",
                "--suite",
                "smoke",
                "--environment-label",
                "staging",
                "--run-label",
                "20260326t153000z",
                "--credentials-source-ref",
                "staging-shared-qa",
                "--doc-context-path",
                "docs/exec-plans/current/epics/automated_testing/experiment/prd.md",
            ],
            check=False,
            capture_output=True,
            text=True,
            cwd=ROOT.parent,
        )

        self.assertEqual(result.returncode, 0)
        payload = json.loads(result.stdout)
        self.assertTrue(payload["ok"])
        self.assertEqual(len(payload["requests"]), 2)
        self.assertEqual(payload["requests"][0]["suite_run_id"], "smoke-20260326t153000z")


if __name__ == "__main__":
    unittest.main()
