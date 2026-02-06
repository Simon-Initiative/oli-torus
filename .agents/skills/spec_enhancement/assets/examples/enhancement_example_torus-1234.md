# Enhancement: TOR-1234 - Preserve manual score overrides during regrade

## Problem
Regrade recalculation can overwrite instructor-entered manual score overrides, causing unexpected grade changes.

## Scope
Prevent recalculation from changing scores for attempts with an explicit manual override flag.

## Acceptance Criteria
- AC-001: Regrade leaves `manual_override=true` attempts unchanged.
- AC-002: Regrade continues updating non-overridden attempts.
- AC-003: Existing regrade summary output still reports totals accurately.

## Risks
- Risk: Missed edge case where override flag is absent on older rows.
  - Mitigation: Treat missing flag as `false` and add regression test.

## Test Plan
- Automated:
  - Add regression test covering mixed overridden and non-overridden attempts.
  - Add unit test for override-flag fallback behavior.
- Manual:
  - Run regrade in a section with one overridden and one normal attempt; verify only normal attempt changes.

## Rollout Notes
- No migration required.
- Rollout with existing release process.

## Out of Scope
- Backfilling override metadata for historical reporting exports.
