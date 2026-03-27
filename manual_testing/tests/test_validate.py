from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml

from manual_testing.tools.validation import lint_file, validate_file


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "tools/manualtest.py"


class ValidationTests(unittest.TestCase):
    def test_validate_file_infers_case_type(self) -> None:
        result = validate_file(ROOT / "cases/authoring/authoring_smoke.yml")
        self.assertEqual(result["type"], "case")

    def test_lint_file_reports_missing_suite_paths_and_duplicates(self) -> None:
        issues = lint_file(ROOT / "tests/fixtures/invalid_suite_missing_case.yml", "suite")
        self.assertIn("suite contains duplicate test paths", issues)
        self.assertTrue(any("suite test path does not exist" in issue for issue in issues))

    def test_manualtest_validate_command_returns_json(self) -> None:
        result = subprocess.run(
            ["python3", str(CLI), "validate", str(ROOT / "suites/smoke.yml")],
            check=False,
            capture_output=True,
            text=True,
            cwd=ROOT.parent,
        )

        self.assertEqual(result.returncode, 0)
        payload = json.loads(result.stdout)
        self.assertTrue(payload["ok"])
        self.assertEqual(payload["type"], "suite")

    def test_manualtest_lint_command_fails_with_actionable_issues(self) -> None:
        result = subprocess.run(
            ["python3", str(CLI), "lint", str(ROOT / "tests/fixtures/invalid_suite_missing_case.yml"), "--type", "suite"],
            check=False,
            capture_output=True,
            text=True,
            cwd=ROOT.parent,
        )

        self.assertEqual(result.returncode, 1)
        payload = json.loads(result.stdout)
        self.assertFalse(payload["ok"])
        self.assertIn("suite contains duplicate test paths", payload["issues"])

    def test_manualtest_convert_command_writes_yaml(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            result = subprocess.run(
                [
                    "python3",
                    str(CLI),
                    "convert",
                    "--input",
                    str(ROOT / "tests/fixtures/convert_input.csv"),
                    "--output-dir",
                    temp_dir,
                ],
                check=False,
                capture_output=True,
                text=True,
                cwd=ROOT.parent,
            )

            self.assertEqual(result.returncode, 0)
            payload = json.loads(result.stdout)
            self.assertTrue(payload["ok"])

            output_case = Path(temp_dir) / "delivery_csv.yml"
            self.assertTrue(output_case.exists())
            document = yaml.safe_load(output_case.read_text())
            self.assertEqual(document["domain"], "delivery")


if __name__ == "__main__":
    unittest.main()
