# Phase 1 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/upgrade_data_capture_parity`
Phase: `1 - Freeze The Minimal Contract`

## Scope from plan.md

- Inventory existing attempt and media producers and freeze their current attribution roles.
- Record v0.33.0 enrollment and correctness semantics as golden expected rows.
- Define minimum attribution and raw activity fields, durable condition evidence, privacy limits,
  assignment scopes, Thompson evidence, and historical missing-field behavior.

## Implementation Blocks

- [x] Core behavior changes (executable test contract only; no runtime behavior changed)
- [x] Data or interface changes (minimum contracts documented; no production schema changed)
- [x] Access-control or safety checks (privacy denylist and durable scoping documented)
- [x] Observability or operational updates when needed (not applicable to contract-only phase)

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Focused verification:

- `mix test test/oli/analytics/xapi/schema_validator_test.exs test/oli/analytics/xapi/upgrade_data_capture_parity_contract_test.exs` - 7 tests, 0 failures.
- `mix format --check-formatted test/support/fixtures/upgrade_data_capture_parity_fixtures.ex test/oli/analytics/xapi/upgrade_data_capture_parity_contract_test.exs` - passed.
- `mix compile` - passed.
- `git diff --check` (applied to each new untracked file with `--no-index`) - passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged (no design divergence)
- [x] Open questions added to docs when needed (none)

## Review Loop

- Round 1 findings: privacy validation used a denylist instead of the required allowlist; direct
  part/activity producer shapes and unattributed media host preservation were not frozen.
- Round 1 fixes: added an explicit bounded attribution-field allowlist; derived part, activity,
  page, and media fixtures from the current production event builders; added unattributed media and
  historical attempt hosts; asserted exact existing roles and attribution types.
- Round 2 findings: synthetic attribution fields diverged from the production builders, the xAPI
  schema still required retired `decision_point_id`, direct part reward evidence was not frozen,
  and Thompson-specific evidence assertions were incomplete.
- Round 2 fixes: built attribution fixtures through `Oli.Experiments.XAPI.Attributions`, aligned the
  schema requirement with current output, added direct reward coverage, and pinned Thompson
  algorithm, policy version, stable keys, linkage, source, and value. Final security, performance,
  and Elixir re-reviews reported no findings.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
