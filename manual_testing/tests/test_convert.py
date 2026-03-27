from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import yaml

from manual_testing.tools.conversion import convert_csv_to_cases


ROOT = Path(__file__).resolve().parents[1]


class ConversionTests(unittest.TestCase):
    def test_convert_csv_to_cases_preserves_text_and_warnings(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output_dir = Path(temp_dir)
            results = convert_csv_to_cases(
                ROOT / "tests/fixtures/convert_input.csv",
                output_dir,
            )

            self.assertEqual(len(results), 2)

            authoring_case = yaml.safe_load((output_dir / "authoring_csv.yml").read_text())
            self.assertEqual(authoring_case["title"], "Authoring CSV Case")
            self.assertEqual(authoring_case["description"], "Converted from spreadsheet")
            self.assertEqual(authoring_case["steps"][0]["instruction"], "Open the project overview")
            self.assertEqual(authoring_case["expected"][1]["description"], "Editable page loads")
            self.assertIn("Keep wording as-is", authoring_case["notes"])
            self.assertIn("Project exists", authoring_case["preconditions"])
            self.assertIn("User can sign in", authoring_case["preconditions"])
            self.assertEqual(authoring_case["source"]["origin"], "csv")
            self.assertTrue(authoring_case["source"]["warnings"])

    def test_convert_requires_test_id(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            broken_csv = Path(temp_dir) / "broken.csv"
            broken_csv.write_text(
                "test_id,title,step_id,step_instruction,expected_id,expected_description\n"
                ",No ID,step_1,Do something,expect_1,See something\n"
            )

            with self.assertRaises(ValueError):
                convert_csv_to_cases(broken_csv, Path(temp_dir) / "out")


if __name__ == "__main__":
    unittest.main()
