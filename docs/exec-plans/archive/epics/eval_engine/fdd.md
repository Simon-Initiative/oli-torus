# Eval Engine Lambda Migration - Functional Design Document

## 1. Executive Summary

This design moves the dynamic-question evaluator into Torus as a Node Lambda bundle rooted at `assets/src/eval_engine`, keeps `vm2` for the first migration, and replaces the current REST hop with direct `ExAws.Lambda.invoke` from Torus. The simplest adequate design is to reuse the existing node Lambda build path already used for the rules engine, add a second `eval` bundle entry, and preserve the browser-facing `/api/v1/variables` contract.

The design intentionally does not replace `vm2`, add a public HTTP layer, or introduce new storage. Instead, it tightens the current transport and ownership boundaries, migrates the relevant `authoring-eval` tests into this repository, and keeps rollback available through existing provider configuration.

## 2. Requirements & Assumptions

- Functional requirements:
  - `FR-001`: move the evaluator implementation into `assets/src/eval_engine` and make Lambda the execution target.
  - `FR-002`: retain `vm2` and preserve current first-generation and module-mode evaluator semantics.
  - `FR-003`: compile the evaluator through `assets/webpack.config.node.js` into a single CommonJS artifact.
  - `FR-004`: implement `VariableSubstitution.LambdaImpl` without changing the `/api/v1/variables` browser contract.
  - `FR-005`: preserve the evaluator payload and response semantics for `vars`, `count`, single execution, batch execution, and module export handling.
  - `FR-006`: migrate the relevant `authoring-eval` tests into Torus and require them to pass here.
  - `FR-007`: harden the Lambda runtime and `vm2` configuration.
  - `FR-008`: preserve config-based REST/Lambda provider rollback.
- Non-functional requirements:
  - Least-privilege Lambda posture, explicit failure behavior, and operational visibility are mandatory.
  - No new database schema or feature-flag work is required.
  - Build and test flow should align with existing Torus tooling.
- Acceptance-criteria trace targets:
  - `AC-001`: node build emits a single evaluator artifact from `assets/src/eval_engine`.
  - `AC-002`: Lambda response shape matches the current Torus evaluator contract.
  - `AC-003`: `vm2` remains in use and is hardened.
  - `AC-004`: migrated evaluator passes corpus-based regression checks.
  - `AC-005`: `/api/v1/variables` works through `LambdaImpl`.
  - `AC-006`: REST fallback still works for rollback.
  - `AC-007`: malformed input and runtime failure paths are deterministic and covered by tests.
  - `AC-008`: migrated `authoring-eval` tests and new targeted tests pass in Torus.
  - `AC-009`: deployed Lambda configuration is least privilege and bounded.
  - `AC-010`: invocation outcomes and latency are observable without leaking payload data.
- Assumptions:
  - Phase 1 can reuse the top-level `assets/package.json`; no nested `assets/src/eval_engine/package.json` is required for the initial implementation.
  - The simplest artifact name is `priv/node/eval.js`, parallel to the existing `rules` bundle.
  - Only Torus needs to call the evaluator in Phase 1.

## 3. Repository Context Summary

- What we know:
  - `lib/oli_web/controllers/api/variable_evaluation_controller.ex` is the browser-facing authoring endpoint and currently assembles a single variable-substitution transformer before calling `Strategy.provide_batch_context/1`.
  - `lib/oli/activities/transformers/variable_substitution/rest_impl.ex` already defines the current logical evaluator payload and expected decoded return shape.
  - `lib/oli/activities/transformers/variable_substitution/lambda_impl.ex` exists but is entirely stubbed.
  - `lib/oli/delivery/attempts/activity_lifecycle/lambda.ex` shows the established Torus pattern for direct Lambda invocation with `ExAws.Lambda.invoke`.
  - `assets/webpack.config.node.js`, `assets/tsconfig.node.json`, and the `deploy-node` script in `assets/package.json` already bundle the rules Lambda into `priv/node`.
  - The old evaluator code and tests remain available in the sibling `authoring-eval` repository and are the migration source of truth for evaluator behavior.
- Confirmed implementation decisions:
  - `vm2` packages cleanly through the shared `assets` dependency graph for Phase 1, so no local manifest was needed.
  - The current ignored `count` value in `VariableEvaluationController` is preserved intentionally as legacy Phase 1 behavior.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

The design introduces four concrete responsibilities:

1. Node evaluator bundle in `assets/src/eval_engine`
   - Owns payload validation, evaluation orchestration, `vm2` execution, output normalization, and structured Lambda response generation.
   - Replaces Express, HAProxy, and standalone Docker concerns from `authoring-eval`.

2. Node build extension in `assets/webpack.config.node.js` and `assets/tsconfig.node.json`
   - Adds an `eval` entry alongside `rules`.
   - Emits `priv/node/eval.js` as the deployment artifact.

3. Elixir provider implementation in `VariableSubstitution.LambdaImpl`
   - Invokes the Lambda directly via AWS SDK.
   - Decodes Lambda payloads into the same `{:ok, [evaluations]}` shape currently returned by `RestImpl`.
   - Preserves `substitute/2` by delegating to `Common.replace_variables/2`, matching current provider behavior.

4. Controller and strategy threading
   - `VariableEvaluationController` preserves the current legacy behavior and continues not to use authoring-provided `count` to change evaluator execution.
   - Existing transformer/runtime callers continue using default count `1`.

### 4.2 State & Data Flow

Authoring evaluation flow:

1. Browser posts `{data, count}` to `/api/v1/variables`.
2. Controller converts `data` into a single `%Transformation{}`.
3. Controller preserves current behavior and calls `Strategy.provide_batch_context([assembled_transformer])`.
4. `LambdaImpl` transforms Torus data into the evaluator payload:
   - `vars: [[%{variable: ..., expression: ...}, ...]]`
   - `count: 1`
5. Lambda handler validates payload, runs evaluator logic, and returns a JSON array whose first element is the evaluation list for the single transformer request.
6. `LambdaImpl` decodes the payload into `{:ok, [evaluations]}`.
7. Controller returns `%{"result" => "success", "evaluations" => evaluations}` exactly as today.

Delivery/runtime variable substitution flow:

1. Existing transformer pipeline continues calling `VariableSubstitution.provide_batch_context(transformers)`.
2. Strategy default count remains `1`.
3. `LambdaImpl` batches all transformer payloads and returns one evaluation list per transformer, matching current `RestImpl` semantics.

### 4.3 Lifecycle & Ownership

- Source ownership moves from the sibling `authoring-eval` repository to Torus:
  - evaluator runtime code under `assets/src/eval_engine`
  - evaluator tests under Torus `assets/test` or equivalent Jest-owned location
  - evaluator fixtures copied into Torus under a dedicated test fixture path
- Runtime ownership splits cleanly:
  - Node Lambda owns script execution and response shaping
  - Elixir provider owns AWS invocation, response decoding, config selection, and API integration
  - Browser remains unchanged and unaware of transport choice
- Recommended file layout:
  - `assets/src/eval_engine/index.ts`
  - `assets/src/eval_engine/contracts.ts`
  - `assets/src/eval_engine/evaluator.ts`
  - `assets/src/eval_engine/first_gen.ts`
  - `assets/src/eval_engine/module_gen.ts`
  - `assets/src/eval_engine/sandbox.ts`
  - `assets/test/eval_engine/*.test.ts`
  - `assets/test/fixtures/eval-engine/*`

### 4.4 Alternatives Considered

- Keep the standalone `authoring-eval` service and only change deployment:
  - Rejected because it preserves split ownership, old toolchain, and external operational dependency.
- Put the evaluator behind API Gateway or a Lambda Function URL:
  - Rejected because no non-Torus callers need the service in Phase 1, and direct SDK invocation is simpler, more private, and consistent with existing Lambda usage.
- Replace `vm2` during the initial migration:
  - Rejected because it increases migration scope and behavior-risk at the same time as transport and ownership are changing.
- Add a nested `assets/src/eval_engine/package.json` from the start:
  - Rejected as the default because the shared `assets` package and webpack build are already the canonical node-bundle path; a nested manifest remains a contingency if packaging proves difficult.

## 5. Interfaces

- Elixir strategy/provider interface:
  - Preserve the existing one-arity `provide_batch_context(transformers)` interface in Phase 1.
  - `RestImpl`, `LambdaImpl`, `NodeImpl`, and `NoOpImpl` continue to operate with the default count behavior.

- Lambda invocation payload:
  ```json
  {
    "vars": [
      [
        { "variable": "V1", "expression": "1 + 1" }
      ]
    ],
    "count": 1
  }
  ```

- Lambda success response payload:
  ```json
  [
    [
      { "variable": "V1", "result": 2, "errored": false }
    ]
  ]
  ```

- Lambda failure contract:
  - Handler returns a JSON object with a stable error envelope for malformed request or internal failure.
  - `LambdaImpl` maps invocation or decode failures to `{:error, reason}`.
  - Controller preserves current `500 server error` behavior for failed authoring evaluation requests.

- Node handler module contract:
  - Export a single Lambda handler from `assets/src/eval_engine/index.ts`.
  - Handler accepts plain JSON event payloads and returns JSON-serializable data only.

- Migrated test surface:
  - Migrate relevant tests from `authoring-eval/test`:
    - `convert-test.ts`
    - `oli-test.ts`
    - `em-test.ts`
    - `batch-test.ts`
    - `all-test.ts`
  - Do not migrate load-testing or container-specific artifacts such as `loadTester.js` or `artillery.yml`.

## 6. Data Model & Storage

- No application database schema changes.
- No new persistent Torus storage is required for evaluator requests or results.
- New repository-level artifacts only:
  - Node source files under `assets/src/eval_engine`
  - Jest tests and fixtures under Torus
  - node bundle artifact under `priv/node/eval.js`
- Lambda runtime may use memory and ephemeral disk as provided by AWS, but the design assumes no dependence on persisted warm-state correctness.

## 7. Consistency & Transactions

- There are no cross-request transactional guarantees because evaluator execution is stateless.
- Consistency boundary is request-local:
  - input payload validated
  - evaluator run
  - result normalized
  - response decoded by Torus
- Provider consistency rule:
  - `LambdaImpl` must decode successful Lambda responses into the exact same structural shape that `RestImpl` returns today.
- Rollback consistency rule:
  - REST and Lambda providers must remain semantically interchangeable under the same controller and transformer call paths.

## 8. Caching Strategy

- Application-level caching: N/A for Phase 1.
- Lambda warm-state reuse must not be relied upon for correctness.
- The node bundle should minimize initialization cost by keeping imports narrow and avoiding request-time dynamic dependency loading beyond evaluator setup.

## 9. Performance & Scalability Posture

- Primary performance posture is operational simplicity, not new caching.
- Keep the evaluator Lambda package small by:
  - bundling only the evaluator entry and its dependencies
  - avoiding browser-only imports in the node bundle
  - reusing the focused node webpack config
- Keep runtime bounded by:
  - `vm2` timeout
  - request validation for variable count and output shape
  - Lambda timeout and memory limits
- No production performance budget is introduced in this FDD, but the design must make cold starts and invocation latency measurable per `AC-010`.

## 10. Failure Modes & Resilience

- Malformed request payload:
  - Node handler returns a deterministic validation failure envelope.
  - `LambdaImpl` returns `{:error, reason}` and controller returns server error for authoring API callers.
- Lambda invocation failure or AWS SDK error:
  - `LambdaImpl` logs a bounded error and returns `{:error, reason}`.
- Lambda success with malformed payload:
  - `LambdaImpl` treats decode/shape mismatch as failure rather than passing partial data forward.
- Sandbox execution failure:
  - Evaluator preserves per-variable error semantics where the current service does so.
  - Non-serializable outputs are normalized or rejected before crossing the Lambda boundary.
- Warm-runtime leakage concern:
  - No request data is cached for correctness; handler reconstructs execution context for every invocation.

## 11. Observability

- Elixir-side observability:
  - Add structured logging in `LambdaImpl` for invoke start/failure/success with function name, transport type, and bounded status metadata.
  - Add a telemetry span around invocation and response decoding with outcome and duration metadata to satisfy `AC-010`.
- Lambda-side observability:
  - Log request-level outcome category and duration, but never log raw script bodies or raw learner/authored payloads.
  - Include a small set of safe metadata such as number of transformers, requested count, and top-level error category.
- Operational readiness for `AC-009` and `AC-010` depends on documenting the expected Lambda timeout, memory, region, function name, and IAM posture in deployment configuration.

## 12. Security & Privacy

- `vm2` is retained, but is not treated as the main security boundary.
- Node evaluator hardening requirements:
  - keep `vm2`
  - set `allowAsync: false`
  - set `eval: false`
  - set `wasm: false`
  - reject or sanitize non-plain-object outputs
- Lambda deployment posture:
  - dedicated function
  - least-privilege IAM role
  - no unnecessary secrets
  - no unnecessary VPC attachment
  - bounded timeout and memory
- Privacy posture:
  - do not log authored expressions or evaluation results verbatim unless explicitly scrubbed
  - keep telemetry payloads metadata-only

## 13. Testing Strategy

- Node/Jest tests:
  - migrate the relevant `authoring-eval` tests into Torus for `AC-004` and `AC-008`
  - add handler-contract tests for `AC-001`, `AC-002`, and `AC-007`
  - add explicit `vm2` configuration tests for `AC-003`
- Elixir tests:
  - add `LambdaImpl` tests covering success, invocation failure, payload decode failure, and fallback semantics for `AC-005`, `AC-006`, and `AC-007`
  - add controller tests for `/api/v1/variables` with forwarded `count` and provider-driven results for `AC-005`
- Corpus regression:
  - copy `authoring-eval/data/all.json` or an equivalent Torus fixture and run it against the migrated evaluator for `AC-004`
- Manual/operational checks:
  - confirm deployed Lambda config, IAM, timeout, and memory for `AC-009`
  - confirm telemetry/log output is present and sanitized for `AC-010`

## 14. Backwards Compatibility

- Browser contract remains `/api/v1/variables` with unchanged success payload shape.
- Authoring-provided `count` remains a preserved legacy no-op in Phase 1.
- Existing transformer/runtime callers continue to use default count `1`.
- REST provider remains available for rollback via configuration.
- No public HTTP evaluator surface is required after cutover because there are no non-Torus Phase 1 callers.
- No database migration, data backfill, or client rewrite is required.

## 15. Risks & Mitigations

- Shared-strategy signature changes could affect non-authoring callers:
  - keep one-arity default wrappers and use two-arity only where count forwarding is required.
- `vm2` packaging or runtime incompatibility under the shared `assets` toolchain:
  - start with the shared package; introduce a nested package manifest only if build evidence requires it.
- Test migration may copy obsolete expectations from Node 8:
  - migrate selectively, keep behavior-focused tests, and adapt infrastructure-only assumptions to the new toolchain.
- Direct Lambda invocation could produce opaque failures if payload decoding is loose:
  - require explicit decode and shape validation in `LambdaImpl` before returning success.

## 16. Open Questions & Follow-ups

- If `vm2` build friction appears under the shared `assets` package, decide whether to add `assets/src/eval_engine/package.json` or a dedicated packaging sub-step.

## 17. References

- `docs/exec-plans/current/epics/eval_engine/prd.md`
- `docs/exec-plans/current/epics/eval_engine/requirements.yml`
- `docs/exec-plans/current/epics/eval_engine/approach.md`
- `lib/oli/activities/transformers/variable_substitution/lambda_impl.ex`
- `lib/oli/activities/transformers/variable_substitution/rest_impl.ex`
- `lib/oli_web/controllers/api/variable_evaluation_controller.ex`
- `lib/oli/delivery/attempts/activity_lifecycle/lambda.ex`
- `assets/webpack.config.node.js`
- `assets/tsconfig.node.json`
- `assets/package.json`
- `docs/STACK.md`
- `docs/TESTING.md`
- `docs/OPERATIONS.md`
