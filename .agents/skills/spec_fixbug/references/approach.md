# Approach

1. Read the ticket and restate expected vs actual behavior.
2. Reproduce the failure locally when possible.
3. Assess whether existing `Oli.Scenarios` infrastructure can represent the bug workflow.
4. Add a failing regression test first (ExUnit).
5. Implement the smallest fix that makes the test pass.
6. If scenario applicability is true, add/update a scenario regression test for end-to-end bug demonstration.
7. Run targeted tests and any directly affected suites.
8. Confirm no scope creep or unrelated refactors were introduced.
9. Summarize change, verification, and residual risk.
