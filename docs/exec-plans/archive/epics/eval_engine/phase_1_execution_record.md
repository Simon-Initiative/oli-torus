# Phase 1 Execution Record

Work item: `docs/exec-plans/current/epics/eval_engine`
Phase: `1`

## Scope from plan.md
- Establish the Torus-owned evaluator code location, bundle target, and migrated regression fixtures/tests.
- Create `assets/src/eval_engine`, extend the node bundle path, and migrate the relevant `authoring-eval` evaluator tests and fixtures into Torus.

## Implementation Blocks
- [x] Core behavior changes
  Added the Phase 1 evaluator source under `assets/src/eval_engine`, including the migrated runtime modules and a node bundle entrypoint.
- [x] Data or interface changes
  Extended `assets/webpack.config.node.js` and `assets/tsconfig.node.json` to compile an `eval` artifact to `priv/node/eval.js`, and added the required evaluator dependencies to `assets/package.json`.
- [x] Access-control or safety checks
  Preserved the existing evaluator runtime behavior in-repo without broadening its scope. Phase 1 retains `vm2` as planned and keeps hardening work for Phase 2.
- [x] Observability or operational updates when needed
  Not applicable in Phase 1 beyond confirming the existing node deployment path can bundle the evaluator artifact.

## Test Blocks
- [x] Tests added or updated
  Migrated `convert_test.ts`, `oli_test.ts`, `em_test.ts`, `batch_test.ts`, and `all_test.ts`, plus the `all.json` corpus fixture, into Torus under `assets/test/eval_engine` and `assets/test/fixtures/eval-engine`.
- [x] Required verification commands run
- [x] Results captured
  `cd assets && yarn deploy-node`
  `cd assets && yarn test eval_engine`
  `python3 /Users/darren/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/eval_engine --check all`
  All commands passed. `yarn deploy-node` emitted `priv/node/eval.js` and completed with the expected `vm2` webpack warnings about dynamic requires and optional `coffee-script` resolution. `yarn test eval_engine` passed all 5 suites and 567 tests.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  Synced the PRD and FDD to record the now-resolved Phase 1 decisions that the shared top-level `assets` package is sufficient and that legacy `count` behavior remains intentional.
- [x] Open questions added to docs when needed
  No new open questions were introduced in Phase 1.

## Review Loop
- Round 1 findings:
  The migrated `oli_test.ts` suite still contained two upstream loops written as `Array(0, 20).forEach(...)`, which meant the random-path assertions never actually ran.
- Round 1 fixes:
  Replaced those loops with `Array.from({ length: 20 }).forEach(...)` so the migrated tests execute the intended repeated assertions.
- Round 2 findings (optional):
  No further Phase 1 review findings after the test fix. Residual risk is limited to the expected `vm2` webpack warnings during bundling and the planned Phase 2 `vm2` hardening work.
- Round 2 fixes (optional):
  N/A

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
