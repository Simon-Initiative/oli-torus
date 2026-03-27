from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SKILLS_ROOT = ROOT / ".agents" / "skills"
MANUAL_TESTING_SKILLS_ROOT = ROOT / "manual_testing" / "skills"


class AgentSkillTests(unittest.TestCase):
    def test_manual_testing_skills_exist(self) -> None:
        expected_paths = [
            SKILLS_ROOT / "manual_testing_validate" / "SKILL.md",
            MANUAL_TESTING_SKILLS_ROOT / "manual_testing_run" / "SKILL.md",
        ]

        for path in expected_paths:
            self.assertTrue(path.exists(), f"Missing skill file: {path}")

    def test_skill_docs_reference_expected_tooling_entrypoints(self) -> None:
        expectations = {
            SKILLS_ROOT / "manual_testing_validate" / "SKILL.md": [
                "manualtest.py validate",
                "manualtest.py lint",
            ],
        }

        for path, fragments in expectations.items():
            text = path.read_text()
            for fragment in fragments:
                self.assertIn(fragment, text, f"{path} should mention {fragment!r}")

    def test_manual_testing_run_skill_is_repo_local_and_execution_focused(self) -> None:
        skill_path = MANUAL_TESTING_SKILLS_ROOT / "manual_testing_run" / "SKILL.md"
        text = skill_path.read_text()

        self.assertFalse(
            (SKILLS_ROOT / "manual_testing_run" / "SKILL.md").exists(),
            "manual_testing_run should not live under .agents/skills",
        )
        self.assertIn("web browser", text)
        self.assertIn("manual test case", text)
        self.assertIn("references/torus_overview.md", text)
        self.assertIn("references/user_roles.md", text)
        self.assertIn("things_i_have_learned_about_using_torus.md", text)
        self.assertIn("Read this file before every test run", (MANUAL_TESTING_SKILLS_ROOT / "manual_testing_run" / "references" / "things_i_have_learned_about_using_torus.md").read_text())


if __name__ == "__main__":
    unittest.main()
