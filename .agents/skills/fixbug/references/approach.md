# Approach

1. Read the ticket and restate expected vs actual behavior.
2. Reproduce the failure locally when possible.
3. Add a failing regression test first (ExUnit).
4. Implement the smallest fix that makes the test pass.
5. Run targeted tests and any directly affected suites.
6. Confirm no scope creep or unrelated refactors were introduced.
7. Summarize change, verification, and residual risk.
