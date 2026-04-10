# LTI Login Optional Params - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/lti-login-optional-params/prd.md`
- FDD: `docs/exec-plans/current/lti-login-optional-params/fdd.md`

## Scope
Implement LMS-parity optional LTI login parameters for Torus outbound external-tool launches by adding `lti_deployment_id` and a signed compact `lti_message_hint` to the authoring, delivery, and deep-linking launch-details APIs, preserving pass-through behavior in the launch form, adding lightweight debug logging, and covering the behavior with focused unit and controller tests. The work explicitly excludes inbound Torus-as-tool `/lti/login` behavior and avoids new persistence, feature flags, or backend/frontend integration tests.

## Clarifications & Default Assumptions
- The authoritative work-item artifacts are [prd.md](./docs/exec-plans/current/lti-login-optional-params/prd.md) and [fdd.md](./docs/exec-plans/current/lti-login-optional-params/fdd.md).
- `lti_message_hint` is implemented as a compact signed token with minimal launch context and an LTI-specific signing salt.
- `lti_deployment_id` is sourced from the existing `LtiExternalToolActivityDeployment.deployment_id`.
- The implementation keeps launch-param assembly server-owned in `OliWeb.Api.LtiController`; no new standalone domain module is required unless a new external-tool launch surface appears later.
- API response-shape assertions and form-rendering assertions must remain separate unit-level checks; do not add backend/frontend integration tests for this work item.
- No other external-tool launch surfaces exist today beyond project launch details, section launch details, and section deep-linking launch details.
- Lightweight debug logging for launch-param issuance is in scope and must not log raw signed token payloads or other sensitive values.

## Phase 1: Backend Launch Param Builder
- Goal: Establish the shared backend path for optional external-tool login parameter generation.
- Tasks:
  - [ ] Add a private launch-param builder in `OliWeb.Api.LtiController` that centralizes authoring, delivery, and deep-linking param assembly.
  - [ ] Add signed `lti_message_hint` issuance with a dedicated LTI-specific salt and minimal launch-context payload.
  - [ ] Add `lti_deployment_id` to the shared builder from the resolved external-tool deployment row.
  - [ ] Ensure the builder omits nil optional values instead of returning empty strings.
  - [ ] Keep deep-linking-specific extras such as `lti_message_type` composable through the shared builder.
- Testing Tasks:
  - [ ] Add unit-level coverage for the token issuance helper, including sign/verify behavior and minimal payload assertions.
  - [ ] Add focused backend assertions for nil omission behavior in the shared builder or controller boundary.
  - [ ] Run targeted backend tests for the controller module or helper extraction point.
  - Command(s): `mix test test/oli_web/controllers/api/lti_controller_test.exs`, `mix format`
- Definition of Done:
  - One backend path exists for composing external-tool launch params across all in-scope endpoints.
  - Signed `lti_message_hint` generation and `lti_deployment_id` inclusion satisfy `FR-001`, `FR-002`, and `FR-005`.
  - Nil optional fields are omitted rather than serialized as blank values, covering `AC-004`.
- Gate:
  - No response-contract or logging work proceeds until the shared builder and signed token issuance are implemented and testable.
- Dependencies:
  - None.
- Parallelizable Work:
  - `lti_message_hint` signing helper work and `lti_deployment_id` builder wiring can proceed in parallel once the shared builder shape is agreed.

## Phase 2: API Contract And Endpoint Parity
- Goal: Apply the shared builder to all in-scope launch-details endpoints and lock the API contract with tests.
- Tasks:
  - [ ] Refactor project `launch_details` to use the shared builder and include `lti_deployment_id` plus `lti_message_hint`.
  - [ ] Refactor section `launch_details` to use the shared builder and include `lti_deployment_id` plus `lti_message_hint`.
  - [ ] Refactor `deep_linking_launch_details` to use the shared builder while preserving `lti_message_type: "LtiDeepLinkingRequest"`.
  - [ ] Update `assets/src/data/persistence/lti_platform.ts` so the launch-details contract includes the optional fields.
  - [ ] Confirm the signed token differs from `login_hint` and changes appropriately for deep-linking context.
- Testing Tasks:
  - [ ] Extend `test/oli_web/controllers/api/lti_controller_test.exs` for authoring and delivery launch details to assert `lti_deployment_id` and `lti_message_hint` presence plus `lti_message_hint != login_hint`.
  - [ ] Extend `test/oli_web/controllers/api/lti_controller_integration_test.exs` for authoring, delivery, and deep-linking response shape to include the new keys.
  - [ ] Add deep-linking parity assertions showing the signed token changes when `lti_message_type` differs.
  - [ ] Run targeted API controller and integration tests.
  - Command(s): `mix test test/oli_web/controllers/api/lti_controller_test.exs test/oli_web/controllers/api/lti_controller_integration_test.exs`, `mix format`
- Definition of Done:
  - All three in-scope launch-details endpoints return consistent optional login params through one contract.
  - The TypeScript contract matches the backend response shape.
  - API coverage satisfies `FR-003`, `AC-001`, and `AC-003`.
- Gate:
  - No form-rendering signoff occurs until all three API endpoints are aligned and controller tests are green.
- Dependencies:
  - Phase 1.
- Parallelizable Work:
  - TypeScript type updates can proceed in parallel with controller test additions after the response shape is fixed.

## Phase 3: Form Pass-Through And Rendering Tests
- Goal: Prove the client-side launch form preserves the new optional params without adding end-to-end integration coupling.
- Tasks:
  - [ ] Add unit-level form-rendering assertions for hidden inputs carrying `lti_deployment_id` and `lti_message_hint`.
  - [ ] Keep form pass-through testing isolated from API response tests; do not wire backend and frontend together for a single integration assertion.
  - [ ] If practical, add React-side unit tests for `LTIExternalToolFrame.tsx`; otherwise extend the Phoenix component tests as the repository-native alternative.
  - [ ] Confirm `login_url` remains excluded from hidden-input rendering while the new optional params are included when present.
- Testing Tasks:
  - [ ] Extend [lti_external_tools_test.exs](./test/oli_web/components/delivery/lti_external_tools_test.exs) or add equivalent unit-level component coverage for hidden input rendering.
  - [ ] Add a negative assertion showing omitted optional params do not render empty hidden inputs.
  - [ ] Run the chosen unit test module(s) for launch form rendering.
  - Command(s): `mix test test/oli_web/components/delivery/lti_external_tools_test.exs`, `mix format`
- Definition of Done:
  - Form-rendering tests prove pass-through behavior for `lti_deployment_id` and `lti_message_hint`.
  - The repository has unit-level coverage for AC-002 without introducing backend/frontend integration tests.
- Gate:
  - No final observability or manual QA signoff until form pass-through behavior is explicitly covered by unit tests.
- Dependencies:
  - Phase 2.
- Parallelizable Work:
  - React-side unit-test exploration and Phoenix component-test extension are alternative implementation paths; choose one, do not do both unless needed.

## Phase 4: Observability, Verification, And Release Readiness
- Goal: Finalize lightweight debug logging, run manual verification, and confirm the change is ready for implementation signoff.
- Tasks:
  - [ ] Add lightweight debug logging around external-tool launch param generation for project, section, and deep-linking launch paths.
  - [ ] Ensure logs confirm whether `lti_deployment_id` and `lti_message_hint` were issued without logging raw signed token payloads or other sensitive values.
  - [ ] Review the final touched files for consistency with the signed-token design and absence of hidden frontend mutation.
  - [ ] Reconcile any implementation drift back into the work-item docs if needed.
- Testing Tasks:
  - [ ] Add or finalize assertions for the logging behavior where practical without over-coupling tests to log text.
  - [ ] Run the targeted controller and component test suite for this work item together.
  - [ ] Run compile and formatting gates for touched backend and frontend files.
  - [ ] Perform manual verification of an external-tool launch and inspect the outbound login request with browser tools or an LTI debugger.
  - Command(s): `mix test test/oli_web/controllers/api/lti_controller_test.exs test/oli_web/controllers/api/lti_controller_integration_test.exs test/oli_web/components/delivery/lti_external_tools_test.exs`, `mix compile`, `mix format`
- Definition of Done:
  - Lightweight debug logging exists and is sanitized.
  - Targeted automated tests are green and manual verification confirms the outbound login request includes `lti_deployment_id` and `lti_message_hint`.
  - Final verification satisfies `AC-002` and `AC-005` alongside the earlier controller-coverage criteria.
- Gate:
  - Final signoff requires green targeted tests, sanitized logging, and successful manual verification of the outbound external-tool login request.
- Dependencies:
  - Phases 1 through 3.
- Parallelizable Work:
  - Logging work and manual-verification prep can proceed in parallel once endpoint behavior and form rendering are stable.

## Parallelization Notes
- In Phase 1, shared builder wiring and signed-token helper work are safe to split if both agree on the helper interface and token payload contract.
- In Phase 2, API test updates and TypeScript response-type updates can proceed in parallel once the response shape is fixed.
- In Phase 3, choose either React-side unit tests or Phoenix component-test extension for AC-002; both are not required to meet the plan.
- Phase 4 logging work can overlap with final manual-verification prep, but final signoff must wait for targeted automated tests and sanitized logging review.

## Phase Gate Summary
- Gate A: shared backend builder, signed `lti_message_hint` issuance, and nil omission must be implemented and unit-tested before endpoint parity work proceeds.
- Gate B: project, section, and deep-linking launch-details endpoints must all emit the new optional params through a consistent contract.
- Gate C: unit-level form-rendering coverage must prove pass-through behavior without backend/frontend integration tests.
- Gate D: sanitized debug logging, green targeted tests, and manual verification of the outbound login request are required for final signoff.
