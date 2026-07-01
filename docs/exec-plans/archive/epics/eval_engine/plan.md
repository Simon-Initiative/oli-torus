# Eval Engine Lambda Migration - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/eval_engine/prd.md`
- FDD: `docs/exec-plans/current/epics/eval_engine/fdd.md`

## Scope
Deliver a Phase 1 migration of the dynamic-question evaluator from the standalone `authoring-eval` service into Torus as a Lambda bundle under `assets/src/eval_engine`, keeping `vm2`, preserving the `/api/v1/variables` browser contract, preserving legacy authoring `count` behavior, and maintaining REST-provider rollback. The plan includes migrating the relevant `authoring-eval` unit tests, implementing the Lambda bundle and Elixir provider path, and adding the observability and operational checks required by `AC-001` through `AC-010`.

## Clarifications & Default Assumptions
- Phase 1 does not replace `vm2`; it preserves it and hardens its configuration. `AC-003`
- No non-Torus callers require a public HTTP transport, so there is no API Gateway / Function URL track in this plan.
- Legacy authoring `count` behavior is preserved: the authoring API may receive `count`, but execution continues to use the default count behavior in Phase 1. `AC-005`
- The default artifact target is `priv/node/eval.js`; change only if packaging evidence requires a different name.
- Use the top-level `assets/package.json` and current webpack node build unless `vm2` packaging forces a nested manifest decision.
- Telemetry is enabled by repository policy and must be planned explicitly.
- Feature flags are enabled in the repository but excluded by default; none are planned for this work item.
- Code review is enabled by repository policy and should include requirements, TypeScript, Elixir, security, and performance review before merge.

## Phase 1: Bundle and Source Migration Setup
- Goal: Establish the Torus-owned evaluator code location, bundle target, and migrated regression fixtures/tests. `AC-001` `AC-004` `AC-008`
- Tasks:
  - [ ] Create `assets/src/eval_engine` source skeleton and move or adapt the evaluator runtime modules from `authoring-eval` into Torus.
  - [ ] Decide whether the shared `assets` package can own `vm2`; only introduce `assets/src/eval_engine/package.json` if packaging evidence requires it.
  - [ ] Add a new `eval` entry to `assets/webpack.config.node.js` and broaden `assets/tsconfig.node.json` so the evaluator compiles into a single CommonJS artifact under `priv/node`. `AC-001`
  - [ ] Copy the relevant `authoring-eval` tests into Torus Jest-owned paths and migrate the required fixtures, including the real-world corpus from `authoring-eval/data/all.json` or an equivalent Torus fixture location. `AC-004` `AC-008`
  - [ ] Exclude non-goal artifacts such as load-testing and container-specific files from the migration set.
- Testing Tasks:
  - [ ] Run targeted node bundle compilation to confirm the new artifact is emitted. `AC-001`
  - [ ] Run migrated evaluator unit tests in their new Torus location and fix migration-only failures. `AC-004` `AC-008`
  - Command(s): `cd assets && yarn deploy-node`, `cd assets && yarn test -- eval-engine`
- Definition of Done:
  - `assets/src/eval_engine` exists with runnable evaluator source.
  - `priv/node/eval.js` is emitted by the node bundle flow.
  - Relevant migrated `authoring-eval` tests exist in Torus and execute under Jest.
- Gate:
  - Do not start Lambda/provider integration until the evaluator bundle exists and migrated tests are runnable in Torus. `AC-001` `AC-008`
- Dependencies:
  - Existing PRD, FDD, and requirements artifacts only.
- Parallelizable Work:
  - Safe parallel split between bundle-config work and test/fixture migration work, as long as both converge on the same entrypoint and fixture paths.

## Phase 2: Evaluator Runtime Hardening and Contract Preservation
- Goal: Make the Node evaluator Lambda-safe while preserving legacy semantics and response contracts. `AC-002` `AC-003` `AC-004` `AC-007`
- Tasks:
  - [ ] Implement the Lambda handler entrypoint in `assets/src/eval_engine/index.ts`.
  - [ ] Preserve the existing evaluator payload/response semantics for `vars`, single execution, batch execution, and module-mode output shaping. `AC-002`
  - [ ] Preserve legacy authoring `count` behavior by keeping default-count execution on the authoring path in Phase 1. `AC-005`
  - [ ] Harden `vm2` configuration with `allowAsync: false`, `eval: false`, and `wasm: false`, and add output normalization or rejection for non-serializable values. `AC-003`
  - [ ] Add deterministic handler behavior for malformed input and evaluator/runtime failure envelopes. `AC-007`
- Testing Tasks:
  - [ ] Add Jest tests for handler payload validation, successful contract responses, hardened `vm2` configuration, malformed input handling, and non-serializable output behavior. `AC-002` `AC-003` `AC-007`
  - [ ] Re-run the migrated corpus-backed tests to confirm no functional drift. `AC-004`
  - Command(s): `cd assets && yarn test -- eval-engine`, `cd assets && yarn lint`
- Definition of Done:
  - The Node handler accepts the expected payload shape and returns JSON-serializable responses only.
  - Hardened `vm2` settings are enforced by tests.
  - Malformed input and runtime failure paths are deterministic.
- Gate:
  - Do not start Elixir Lambda provider integration until handler contract tests and migrated evaluator tests pass. `AC-002` `AC-003` `AC-004` `AC-007`
- Dependencies:
  - Phase 1 bundle and test migration complete.
- Parallelizable Work:
  - Handler contract tests and `vm2` hardening tests can be developed in parallel with module/first-generation evaluator refactoring.

## Phase 3: Torus Lambda Provider and API Integration
- Goal: Replace the REST transport with direct Lambda invocation while preserving browser and transformer behavior and maintaining rollback. `AC-005` `AC-006` `AC-007`
- Tasks:
  - [ ] Implement `lib/oli/activities/transformers/variable_substitution/lambda_impl.ex` using the established `ExAws.Lambda.invoke` pattern.
  - [ ] Decode Lambda responses into the same `{:ok, [evaluations]}` shape returned by `RestImpl`. `AC-005`
  - [ ] Preserve `substitute/2` delegation to `Common.replace_variables/2`.
  - [ ] Keep the existing one-arity `provide_batch_context(transformers)` interface for Phase 1 and preserve default count behavior. `AC-005`
  - [ ] Update configuration usage so Lambda provider selection works through the existing `VARIABLE_SUBSTITUTION_PROVIDER`, function name, and region settings.
  - [ ] Preserve and verify REST-provider rollback through config selection. `AC-006`
  - [ ] Keep `VariableEvaluationController` browser response shape unchanged and preserve current legacy `count` handling. `AC-005`
- Testing Tasks:
  - [ ] Add ExUnit coverage for `LambdaImpl` success, AWS invoke failure, payload decode failure, and malformed payload handling. `AC-005` `AC-007`
  - [ ] Add controller tests for `/api/v1/variables` success and failure paths with Lambda and REST provider configurations. `AC-005` `AC-006`
  - Command(s): `mix test test/oli/activities/transformers/variable_substitution_test.exs`, `mix test test/oli_web/controllers/api/variable_evaluation_controller_test.exs`
- Definition of Done:
  - Lambda provider is fully implemented.
  - Authoring requests still receive the existing JSON contract from `/api/v1/variables`.
  - REST rollback remains available through configuration.
- Gate:
  - Do not move to observability/release-readiness until Elixir-side provider and controller tests pass for both Lambda and REST modes. `AC-005` `AC-006` `AC-007`
- Dependencies:
  - Phase 2 handler contract stable.
- Parallelizable Work:
  - LambdaImpl implementation and controller tests can proceed in parallel once the handler payload/response contract is fixed.

## Phase 4: Observability, Operational Readiness, and Release Gates
- Goal: Make the Lambda-backed evaluator deployable, observable, and safe to roll out with rollback confidence. `AC-009` `AC-010`
- Tasks:
  - [ ] Add structured Elixir-side logging and telemetry around Lambda invocation and response decoding. `AC-010`
  - [ ] Add Lambda-side logging for outcome category and duration without exposing raw authored payloads or evaluation results. `AC-010`
  - [ ] Document or codify the expected Lambda function configuration: least-privilege IAM, bounded timeout, bounded memory, region, and function name. `AC-009`
  - [ ] Verify rollout/rollback steps for REST versus Lambda provider selection in a non-production environment.
  - [ ] Prepare code review with requirements, TypeScript, Elixir, security, and performance lenses.
- Testing Tasks:
  - [ ] Run the full targeted Jest and ExUnit suites together as a release gate. `AC-008`
  - [ ] Perform non-production manual verification of provider cutover, rollback, sanitized logs, and observable invocation latency. `AC-009` `AC-010`
  - Command(s): `cd assets && yarn test -- eval-engine`, `mix test test/oli/activities/transformers/variable_substitution_test.exs test/oli_web/controllers/api/variable_evaluation_controller_test.exs`
- Definition of Done:
  - Invocation outcomes and latency are observable without leaking disallowed data.
  - Lambda deployment posture is explicitly least privilege and bounded.
  - Rollout and rollback have been manually verified in non-production.
- Gate:
  - Merge/release only after automated suites pass, non-production rollout checks complete, and review lenses are satisfied. `AC-008` `AC-009` `AC-010`
- Dependencies:
  - Phase 3 integration complete.
- Parallelizable Work:
  - Review preparation and deployment/runbook updates can happen in parallel with telemetry instrumentation once the provider path is stable.

## Parallelization Notes
- Best Phase 1 split:
  - Worker A: webpack/tsconfig/package-path setup and entrypoint scaffolding.
  - Worker B: migrate `authoring-eval` tests and fixtures into Torus.
- Best Phase 2 split:
  - Worker A: handler and evaluator refactor.
  - Worker B: Jest contract/hardening tests.
- Best Phase 3 split:
  - Worker A: `LambdaImpl` implementation.
  - Worker B: controller and provider ExUnit coverage.
- Avoid parallel edits to the same entrypoint files:
  - `assets/webpack.config.node.js`
  - `assets/tsconfig.node.json`
  - `lib/oli/activities/transformers/variable_substitution/lambda_impl.ex`

## Phase Gate Summary
- Gate A: Bundle and migrated test baseline established in Torus. `AC-001` `AC-004` `AC-008`
- Gate B: Lambda handler contract stable and `vm2` hardening proven by tests. `AC-002` `AC-003` `AC-007`
- Gate C: Torus Lambda provider and REST rollback both pass targeted ExUnit/controller verification. `AC-005` `AC-006` `AC-007`
- Gate D: Observability, least-privilege operational posture, and non-production rollout/rollback checks complete. `AC-008` `AC-009` `AC-010`
