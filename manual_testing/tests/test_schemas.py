from __future__ import annotations

import json
import unittest
from pathlib import Path

import yaml

from manual_testing.tools.schema_contracts import (
    SchemaValidationError,
    load_schema,
    validate_against_schema,
)


ROOT = Path(__file__).resolve().parents[1]


class SchemaContractTests(unittest.TestCase):
    def test_valid_case_fixture_matches_schema(self) -> None:
        case_doc = yaml.safe_load((ROOT / "cases/authoring/authoring_smoke.yml").read_text())
        validate_against_schema(case_doc, load_schema("test_case"))

    def test_valid_suite_fixture_matches_schema(self) -> None:
        suite_doc = yaml.safe_load((ROOT / "suites/smoke.yml").read_text())
        validate_against_schema(suite_doc, load_schema("test_suite"))

    def test_valid_run_fixture_matches_schema(self) -> None:
        run_doc = json.loads((ROOT / "tests/fixtures/test_run_passed.json").read_text())
        validate_against_schema(run_doc, load_schema("test_run"))

    def test_invalid_case_missing_expected_fails_validation(self) -> None:
        invalid_case = {
            "id": "bad_case",
            "title": "Bad case",
            "steps": [{"id": "step1", "instruction": "Do something"}],
        }

        with self.assertRaises(SchemaValidationError):
            validate_against_schema(invalid_case, load_schema("test_case"))

    def test_invalid_suite_missing_tests_fails_validation(self) -> None:
        invalid_suite = {
            "id": "bad_suite",
            "title": "Bad suite",
        }

        with self.assertRaises(SchemaValidationError):
            validate_against_schema(invalid_suite, load_schema("test_suite"))

    def test_invalid_run_with_unknown_failure_kind_fails_validation(self) -> None:
        invalid_run = json.loads((ROOT / "tests/fixtures/test_run_passed.json").read_text())
        invalid_run["failure_kind"] = "timed_out"

        with self.assertRaises(SchemaValidationError):
            validate_against_schema(invalid_run, load_schema("test_run"))

    def test_invalid_run_with_unknown_status_fails_validation(self) -> None:
        invalid_run = json.loads((ROOT / "tests/fixtures/test_run_passed.json").read_text())
        invalid_run["status"] = "timeout"

        with self.assertRaises(SchemaValidationError):
            validate_against_schema(invalid_run, load_schema("test_run"))


if __name__ == "__main__":
    unittest.main()
