# Eval Engine Lambda Migration - Product Requirements Document

## 1. Overview
Migrate the dynamic-question evaluation service from the standalone `authoring-eval` Docker/Express deployment to an AWS Lambda implementation owned inside the Torus repository. The new implementation will live in `assets/src/eval_engine`, retain `vm2` for the initial migration, preserve the existing `/api/v1/variables` browser contract, and use the existing node webpack bundling path used by the rules Lambda.

## 2. Background & Problem Statement
- The current evaluator runs outside Torus as an old Node 8 / Express / Docker service, which increases operational overhead and leaves the implementation outside the main repository and deployment flow.
- Torus already has a Lambda-based deployment pattern for the rules engine and already has a stub `VariableSubstitution.LambdaImpl`, but the dynamic-question evaluator still depends on a REST endpoint defaulting to `http://localhost:8000/sandbox`.
- Dynamic questions are a core authoring and delivery capability. Authors need reliable preview/test evaluation in authoring, and learners need stable runtime variable substitution when activities are rendered.
- The migration must not add product churn. The browser-side authoring flow should continue to call Torus `/api/v1/variables`, while Torus switches the backend transport from REST to direct Lambda invocation.
- The migration must keep `vm2` for the initial cut so evaluator semantics stay close to the current service, while still acknowledging that `vm2` is not the ultimate security boundary.

## 3. Goals & Non-Goals
### Goals
- Move the evaluator implementation into Torus under `assets/src/eval_engine`.
- Replace the external containerized Express transport with an AWS Lambda handler.
- Retain `vm2` for the initial migration and harden its configuration for Lambda use.
- Preserve the existing request and response contract used by Torus and the authoring UI.
- Preserve the current legacy handling of authoring `count`, which remains accepted by the browser-facing API but is not used to change evaluator execution in Phase 1.
- Reuse the existing node Lambda build path in `assets/webpack.config.node.js` and `assets/package.json`.
- Migrate the relevant unit tests from the `authoring-eval` codebase into Torus and ensure those migrated tests pass in this repository.
- Add focused automated coverage for evaluator parity, Lambda contracts, and Torus integration.

### Non-Goals
- Replacing `vm2` in the initial migration.
- Redesigning the authoring variable editor UX or the `/api/v1/variables` browser contract.
- Changing the legacy Phase 1 behavior where the authoring evaluation path ignores client-provided `count`.
- Exposing the evaluator as a new public HTTP endpoint if Torus is the only required caller.
- Expanding this work into a broader activity runtime redesign.

## 4. Users & Use Cases
- Author: tests variable expressions and module-style scripts in authoring without needing to know where the evaluator is deployed.
- Learner: receives correctly substituted dynamic-question values during delivery without regression from the infrastructure change.
- Platform engineer: deploys and operates the evaluator through the existing Torus repository, asset pipeline, and AWS Lambda posture instead of a separate Docker service.
- Torus backend: invokes the evaluator through `VariableSubstitution.LambdaImpl` while preserving current response handling.

## 5. UX / UI Requirements
- The authoring variable testing flow continues to work through the existing `/api/v1/variables` Torus endpoint.
- No new browser routes, UI surfaces, or manual deployment controls are introduced for authors or instructors.
- Error behavior remains understandable and non-breaking for authoring variable evaluation failures.
- The migration must not require authors to change how first-generation variable expressions or module-mode scripts are authored.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Reliability: the Lambda-based evaluator must preserve current dynamic-question behavior for supported scripts and return deterministic error payloads for malformed or failed evaluations.
- Security: the initial migration retains `vm2`, but the Lambda function must be treated as the effective isolation boundary with least-privilege IAM, no unnecessary secrets, and bounded runtime configuration.
- Performance: no separate performance certification gate is required for this PRD, but the Lambda implementation must be instrumented well enough to evaluate cold-start and request-latency behavior after cutover.
- Operability: the evaluator must fit Torus’s standard build, deployment, logging, and observability patterns rather than remaining a separate operational surface.
- Maintainability: the source of truth for the evaluator implementation must be inside the Torus repository and follow current TypeScript tooling rather than preserving the old standalone service structure.

## 9. Data, Interfaces & Dependencies
- Input contract remains the logical payload currently sent to the evaluator: `vars` and optional `count`.
- Output contract remains the current evaluation list shape used by Torus controllers and authoring clients.
- Primary backend integration points:
  - `lib/oli/activities/transformers/variable_substitution/lambda_impl.ex`
  - `lib/oli_web/controllers/api/variable_evaluation_controller.ex`
  - `config/config.exs`
  - `config/runtime.exs`
- Primary frontend/build integration points:
  - `assets/src/eval_engine`
  - `assets/webpack.config.node.js`
  - `assets/tsconfig.node.json`
  - `assets/package.json`
- Key code dependencies for the initial migration include `vm2`, the evaluator helper modules now in `authoring-eval`, and the existing node webpack bundle flow used for `assets/src/adaptivity/rules.ts`.

## 10. Repository & Platform Considerations
- Torus is a Phoenix application with focused TypeScript entrypoints under `assets/src`; this migration should preserve that boundary instead of reintroducing a separate service repository at runtime.
- The preferred deployment model is direct Torus-to-Lambda invocation via `ExAws.Lambda.invoke`, consistent with the existing rules engine Lambda pattern.
- The Lambda bundle should be emitted as a CommonJS artifact under `priv/node`, aligned with the current `deploy-node` script.
- The initial migration should prefer reusing the top-level `assets/package.json` and existing webpack node build. A nested `assets/src/eval_engine/package.json` is optional and should only be introduced if dependency packaging requires it.
- Because both TypeScript and Elixir integration points are affected, the implementation will require migration of the relevant `authoring-eval` unit tests into Torus, plus targeted Jest coverage and targeted `mix test` coverage for the Lambda provider and API surface.
- Code review for this work should include requirements, TypeScript, Elixir, security, and performance lenses because the work item changes a PRD, a Lambda bundle, and a backend runtime integration path.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Emit evaluator invocation success/failure telemetry with outcome category, invocation duration, and transport type.
- Track Lambda-specific operational visibility such as invocation errors and request latency so post-cutover regressions can be detected quickly.
- Success signal: authors continue to evaluate dynamic-question variables successfully through `/api/v1/variables` with no required client-side workflow change.
- Success signal: Torus can switch between REST and Lambda providers through configuration during rollout and rollback.

## 13. Risks & Mitigations
- `vm2` remains an in-process sandbox with known escape risk: mitigate by explicitly retaining it only for Phase 1, hardening its config, and treating Lambda permissions and environment as the real blast-radius boundary.
- Behavior drift during migration from the old standalone service: mitigate with parity testing using the existing real-world evaluator corpus and targeted contract tests.
- Losing regression protection that already exists in `authoring-eval`: mitigate by migrating the relevant unit tests into Torus and requiring them to pass before cutover.
- Packaging drift from the existing rules Lambda build flow: mitigate by extending `assets/webpack.config.node.js` and `assets/tsconfig.node.json` instead of inventing a new bundling path.
- Backend cutover regressions in Torus variable substitution: mitigate by implementing `LambdaImpl` behind configuration so REST fallback remains available during rollout.

## 14. Open Questions & Assumptions
### Open Questions
- None for Phase 1 implementation scope. Phase 1 confirmed that the evaluator packages cleanly through the top-level `assets` dependency graph and emits `priv/node/eval.js` without needing a nested `assets/src/eval_engine/package.json`.

### Assumptions
- The initial migration will keep `vm2` and will not change supported script authoring semantics beyond necessary hardening such as disabling async, `eval`, and wasm execution.
- The rules-engine Lambda build path in `assets/webpack.config.node.js` is the canonical model for compiling this evaluator into a single deployable artifact.
- The existing `/api/v1/variables` endpoint remains the browser-facing contract, so no direct frontend contract change is required.
- The current legacy authoring behavior for `count` is preserved in Phase 1: callers may still send it, but Torus continues to evaluate with the existing default behavior rather than introducing new count-driven semantics.
- Configuration-based provider selection is sufficient for rollout and rollback without feature-flag scaffolding.
- The existing `authoring-eval` test suite contains meaningful regression coverage that should be selectively migrated rather than discarded.
- No non-Torus callers require a public HTTP-facing evaluator transport in Phase 1, so direct Torus-to-Lambda invocation is the only required production path.

## 15. QA Plan
- Automated validation:
  - Migrate the relevant `authoring-eval` unit tests into Torus and require them to pass in the new code location.
  - Jest tests for evaluator parity, Lambda handler contract behavior, and node bundle entrypoint behavior.
  - `mix test` coverage for `VariableSubstitution.LambdaImpl`, `VariableEvaluationController`, and provider-selection behavior.
  - Regression coverage using the existing `authoring-eval/data/all.json` corpus or its migrated equivalent.
- Manual validation:
  - Verify authoring variable testing continues to work through `/api/v1/variables` without UI changes.
  - Verify authoring requests that include non-default `count` continue to exhibit the preserved legacy behavior in Phase 1.
  - Verify module-mode evaluation, batch behavior, and failure payloads behave consistently in a Lambda-backed environment.
  - Verify configuration-driven cutover between REST and Lambda providers works in a non-production environment.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
