# Output Requirements

Use a two-stage output contract.

## Stage 1: Pre-Implementation Review
- Jira ticket key and one-line problem statement.
- Brief technical approach (2-4 sentences plus short bullet list).
- Brief implementation plan (3-6 numbered steps).
- Assumptions/defaults and key risks.
- Test strategy and acceptance checks.
- Scenario testing decision:
  - `needed`: yes/no
  - `infrastructure`: supported/unsupported
  - `skill handoff`: `none` | `$spec_scenario` | `$spec_scenario_expand -> $spec_scenario`
- Explicit request for user feedback/approval before implementation.

## Stage 2: Post-Implementation Summary
- What was implemented and key files changed.
- Tests/compile commands run and outcomes.
- Scenario coverage outcome and skills used (`$spec_scenario` and/or `$spec_scenario_expand` when applicable).
- Any scope adjustments from original brief plan.
- Residual risks or follow-up actions.

Do not report or create enhancement-doc artifact paths.
