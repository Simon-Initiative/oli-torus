# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/eval_engine`
Phase: `2`

## Scope from plan.md
- Make the Node evaluator Lambda-safe while preserving legacy semantics and response contracts.
- Implement the Lambda handler entrypoint, harden `vm2`, validate handler payloads, and add deterministic success and failure behavior with targeted Jest coverage.

## Implementation Blocks
- [x] Core behavior changes
  Added the Lambda-facing handler flow in `assets/src/eval_engine/index.ts`, including request validation, deterministic error envelopes, and response-shape normalization for single and batch evaluation paths.
- [x] Data or interface changes
  Added `assets/src/eval_engine/contracts.ts` to define the request, result, and error-envelope types used by the handler and evaluator boundary.
- [x] Access-control or safety checks
  Hardened `vm2` construction in `assets/src/eval_engine/evaluator.ts` with `allowAsync: false`, `eval: false`, `wasm: false`, and preserved JSON-safe normalization at the handler boundary so non-serializable module output is rejected or sanitized before crossing Lambda.
- [x] Observability or operational updates when needed
  Not applicable in Phase 2 beyond preserving the deployable Node artifact and deterministic handler behavior.

## Test Blocks
- [x] Tests added or updated
  Added `assets/test/eval_engine/handler_test.ts` for handler success, validation failure, runtime-failure, and `vm2` hardening coverage. Updated the migrated legacy tests where the original upstream expectations were either unreachable or flaky under the preserved evaluator semantics.
- [x] Required verification commands run
- [x] Results captured
  `cd assets && yarn test eval_engine`
  `cd assets && ./node_modules/.bin/eslint src/eval_engine test/eval_engine`
  `cd assets && yarn deploy-node`
  All commands passed. `yarn test eval_engine` passed 6 suites and 575 tests. `eslint` passed on the eval-engine paths. `yarn deploy-node` emitted `priv/node/eval.js` and completed with the expected `vm2` webpack warnings about dynamic requires and optional `coffee-script` resolution.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  No PRD, FDD, or plan changes were required for Phase 2; the implementation matched the existing work-item decisions.
- [x] Open questions added to docs when needed
  No new open questions were introduced in Phase 2.

## Review Loop
- Round 1 findings:
  The first implementation mistakenly normalized first-generation evaluator values before the Lambda boundary, which changed legacy evaluator behavior and caused corpus regressions in `all_test.ts`.
- Round 1 fixes:
  Moved JSON-safe normalization back to the handler boundary only, preserving the legacy evaluator semantics while keeping Lambda responses JSON-safe.
- Round 2 findings (optional):
  Two migrated test expectations were inaccurate once the handler contract was explicit: the non-serializable module export case is rejected through the legacy aggregate error string, and one decimal-random test legitimately allows `0`.
- Round 2 fixes (optional):
  Updated `handler_test.ts` and `em_test.ts` to reflect the actual preserved evaluator behavior.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
