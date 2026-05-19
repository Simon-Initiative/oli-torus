# Phase 3 Execution Record

Work item: `docs/exec-plans/current/epics/eval_engine`
Phase: `3`

## Scope from plan.md
- Replace the REST transport with direct Lambda invocation while preserving browser and transformer behavior and maintaining rollback.
- Implement `LambdaImpl`, wire provider selection through existing config, preserve legacy authoring `count` behavior, and add targeted ExUnit/controller coverage for Lambda and REST modes.

## Implementation Blocks
- [x] Core behavior changes
  Implemented `lib/oli/activities/transformers/variable_substitution/lambda_impl.ex` to invoke the eval Lambda through `ExAws.Lambda.invoke/3`, preserve `substitute/2` delegation through `Common.replace_variables/2`, and normalize successful Lambda responses into the same `{:ok, [evaluations]}` shape used by `RestImpl`.
- [x] Data or interface changes
  Kept the existing one-arity `provide_batch_context(transformers)` interface and the legacy default-count behavior, while updating runtime provider defaults in `config/runtime.exs` so runtime configuration matches the existing compile-time `RestImpl` fallback and valid REST endpoint default.
- [x] Access-control or safety checks
  Preserved the existing server-side authoring boundary by keeping `/api/v1/variables` behavior unchanged, rejecting malformed Lambda payloads, and ensuring provider failures surface as deterministic `500` responses without exposing raw Lambda error bodies.
- [x] Observability or operational updates when needed
  No new Phase 3 telemetry was added; the work stayed within transport and contract integration. Observability remains planned for Phase 4.

## Test Blocks
- [x] Tests added or updated
  Expanded `test/oli/activities/transformers/variable_substitution_test.exs` with `LambdaImpl` success, AWS failure, decode failure, malformed payload, and `substitute/2` coverage. Added `test/oli_web/controllers/api/variable_evaluation_controller_test.exs` to verify Lambda success/failure, REST rollback success/failure, and preserved legacy `count` handling.
- [x] Required verification commands run
- [x] Results captured
  `mix test test/oli/activities/transformers/variable_substitution_test.exs`
  `mix test test/oli_web/controllers/api/variable_evaluation_controller_test.exs`
  `mix test test/oli/activities/transformers/variable_substitution_test.exs test/oli_web/controllers/api/variable_evaluation_controller_test.exs`
  `python3 /Users/darren/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/eval_engine --check all`
  All commands passed. During verification, the test database initially needed the existing `pending_uploads` migration to be present for app startup; `MIX_ENV=test mix ecto.migrate` confirmed the test schema was up to date before the final passing runs.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  No PRD, FDD, or plan changes were required for Phase 3; the implementation matched the approved work-item decisions.
- [x] Open questions added to docs when needed
  No new open questions were introduced in Phase 3.

## Review Loop
- Round 1 findings:
  The first controller tests incorrectly expected a JSON error envelope on `500` responses, but `VariableEvaluationController` returns the legacy plain-text `"server error"` body. The initial assertions also missed that `ExAws.Lambda.invoke/3` produces a trailing `?` in the operation path when no qualifier is supplied.
- Round 1 fixes:
  Updated the controller failure assertions to expect the legacy plain-text response and corrected the Lambda operation-path assertions in the new tests.
- Round 2 findings (optional):
  No further Elixir, security, or performance findings were identified in the Phase 3 diff. Residual risk is limited to mocked-contract coverage only; there is still no non-production verification yet against a deployed Lambda function with real `ExAws` responses.
- Round 2 fixes (optional):
  N/A

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
