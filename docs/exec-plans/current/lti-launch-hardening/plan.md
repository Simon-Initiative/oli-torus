# LTI Launch Hardening - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/lti-launch-hardening/prd.md`
- FDD: `docs/exec-plans/current/lti-launch-hardening/fdd.md`

## Scope
Deliver the hardened LTI 1.3 launch flow described in the PRD/FDD by introducing a Torus-owned signed launch-state boundary, a Torus-owned login/request-construction path, a storage-assisted browser helper and recovery/error UI, explicit launch-context routing, and structured telemetry. Preserve the current registration, deployment, authorization, enrollment, and section-resolution behavior for valid launches and keep `lti_1p3` as the lower-level validation and protocol boundary.

## Guardrails
- Keep authorization, validation, and replay protection on the Phoenix/server boundary.
- Do not broaden logging of raw `id_token`, cookies, session contents, or full launch claims.
- Preserve the legacy session-backed launch path for registrations/platforms that do not advertise storage capability.
- Do not let immediate post-launch routing depend on `get_latest_user_lti_params/1`.
- Keep any browser helper narrow, controller-rendered, accessible, and auto-continuing when possible.

## Clarifications & Default Assumptions
- The repository-level harness docs requested by the planning skill (`ARCHITECTURE.md`, `harness.yml`, `docs/STACK.md`, `docs/TOOLING.md`, `docs/TESTING.md`, `docs/PRODUCT_SENSE.md`, `docs/FRONTEND.md`, `docs/BACKEND.md`) are not present; this plan uses repository equivalents called out in the FDD, especially `README.md`, `guides/lti/implementing.md`, `guides/lti/config.md`, and `guides/process/testing.md`.
- The first implementation slice should verify early whether Torus can validate launch state from a signed short-lived state token while continuing to rely on `lti_1p3` for nonce, JWT, registration, deployment, and message validation; if a thin adapter is required, keep it local to Torus rather than forking the library.
- `lti_1p3_params.params` should be narrowed only as far as needed for this work item; preserve transitional compatibility for admin/support consumers until the current consumer audit is complete.
- Manual browser validation should prioritize at least one LMS/storage-capable embedded launch and one blocked-cookie or blocked-storage scenario, but automated coverage should remain primarily ExUnit-based with only thin browser smoke coverage if truly needed.
- The administrator-visible compatibility indicator requested in the PRD should be treated as part of observability and supportability for this work item, not as a standalone admin product redesign.
- The smallest acceptable launch-state implementation is a signed, expiring Torus state envelope rather than a new database table or node-local cache, unless later implementation evidence shows single-use server persistence is strictly required.

## Acceptance Criteria Coverage
- Phase 1 covers `AC-002` by proving the Torus-owned state boundary can still pass through the existing `lti_1p3` validation boundary.
- Phase 2 covers `AC-001`, `AC-002`, and `AC-003` by implementing dual-path login construction and capability-based flow selection.
- Phase 3 covers `AC-004`, `AC-005`, `AC-006`, `AC-007`, and `AC-009` by hardening launch recovery, failure classification, stable error rendering, and privacy-safe telemetry.
- Phase 4 covers `AC-008` and `AC-010` by routing from current validated launch context while preserving registration, deployment, tenant, and section boundaries.
- Phase 5 re-validates `AC-001` through `AC-010` through final automated checks, manual verification notes, and harness validation.

## Phase 1: Validate Signed Launch-State Boundary
- Goal: Establish the signed Torus launch-state model and prove the minimum viable boundary with `lti_1p3` before broader controller/UI changes land.
- Tasks:
  - [ ] Audit current `/lti/login` and `/lti/launch` flow boundaries in `lib/oli_web/controllers/lti_controller.ex` and identify the smallest extraction points for Torus-owned login orchestration and state resolution.
  - [ ] Confirm how `Lti_1p3.Tool.LaunchValidation.validate/2` consumes state today and implement the narrowest Torus-side adapter needed to validate against a signed Torus state envelope without weakening existing validation semantics.
  - [ ] Implement a signed, short-lived launch-state envelope carrying only the minimum fields required for launch correlation and validation, such as expected state identity, nonce, issuer/client hint, flow mode, request correlation, and expiry.
  - [ ] Add `Oli.Lti.LaunchState` helpers to issue, verify, decode, and classify the signed state envelope, including deterministic handling for missing, invalid, expired, and mismatched state.
  - [ ] Keep the current Phoenix session write only as a legacy compatibility aid where needed, not as the authoritative source of launch state for hardened flows.
- Testing Tasks:
  - [ ] Add focused domain tests for signed-state issuance, verification, expiry handling, tamper detection, and failure classification.
  - [ ] Add a regression test proving Torus can validate against Torus-issued signed state through the existing `lti_1p3` boundary.
  - Command(s): `mix test test/oli/lti`
- Definition of Done:
  - Launch state is represented by a signed, expiring Torus-owned envelope rather than a new persistence table.
  - The `lti_1p3` validation boundary required for the hardened flow is proven and documented in code/tests.
  - Missing/invalid/mismatched/expired state outcomes are deterministic and test-covered.
- Gate:
  - Do not begin helper-page or controller flow expansion until the validation boundary is proven to work without session-only assumptions.
- Dependencies:
  - None.
- Parallelizable Work:
  - Signed-state helper implementation and domain-test authoring can proceed in parallel once the interface shape is agreed.

## Phase 2: Implement Login Flow Classification and Storage-Assisted Helper Path
- Goal: Move login/request construction into Torus application code and support dual-path launch initiation based on LMS capability signals.
- Tasks:
  - [ ] Implement Torus-owned OIDC login/request construction, replacing direct dependence on `Lti_1p3.Tool.OidcLogin.oidc_login_redirect_url/1` while preserving equivalent protocol parameters and registration scoping.
  - [ ] Add login-path classification logic for legacy session versus client-storage flow using the capability signals defined in the FDD.
  - [ ] Update `login/2` to issue the signed launch-state envelope, write legacy session state where appropriate, and render either a direct redirect response or a Torus intermediary helper page.
  - [ ] Add controller-rendered helper UI under the LTI HTML boundary with accessible markup, auto-continue behavior, and a `<noscript>` fallback message.
  - [ ] Keep helper-page behavior narrow: assist state transport and request continuation only, with no authorization or routing decisions in browser code.
- Testing Tasks:
  - [ ] Add controller tests covering legacy-capable login, storage-capable login, helper-page rendering, and correct request construction parameters.
  - [ ] Add negative tests for malformed initiation requests and unsupported capability combinations.
  - Command(s): `mix test test/oli_web/controllers/lti_controller_test.exs`
- Definition of Done:
  - Torus owns login/request construction for both flow paths.
  - Storage-capable launches render the helper path; non-capable launches remain on the legacy session path.
  - Controller tests cover both login path selections and request-shape expectations.
- Gate:
  - Do not change launch handling or user-facing recovery behavior until dual-path login initiation is stable and test-covered.
- Dependencies:
  - Phase 1.
- Parallelizable Work:
  - Helper-page HTML/CSS/JS implementation can proceed in parallel with controller request-construction work after the login interface is fixed.

## Phase 3: Harden Launch Handling, Recovery, and Stable Error Rendering
- Goal: Complete hardened `/lti/launch` processing with deterministic recovery/error branches and sanitized operational classification.
- Tasks:
  - [ ] Refactor `launch/2` to verify and decode the signed launch-state envelope first, then apply legacy compatibility checks, and finally use recovery inputs only for the storage-assisted path defined in the design.
  - [ ] Add centralized launch-error classification that maps validation and handler failures into stable categories such as `missing_state`, `mismatched_state`, `embedded_storage_blocked`, `recovery_failure`, `invalid_registration`, and `launch_handler_failure`.
  - [ ] Implement stable controller-rendered recovery and launch-error pages with sanitized user copy that distinguishes browser/session failure from LMS configuration failure without leaking sensitive details.
  - [ ] Ensure known launch failures render directly and remain visible instead of cascading into generic 404 behavior.
  - [ ] Emit structured logs, telemetry, and AppSignal tags for flow mode, classification, storage support, embedded context, request id, and safe registration metadata only.
  - [ ] Add the administrator/support-facing compatibility indicator or equivalent observable signal described in the PRD if the implementation path is low-cost within the current admin surfaces; otherwise document the exact observable substitute in the work item.
- Testing Tasks:
  - [ ] Add controller tests for successful storage-assisted launch, missing state, mismatched/consumed state, unsupported storage capability fallback, recovery-page rendering, and stable error-page rendering.
  - [ ] Add tests that assert telemetry/log metadata excludes raw tokens, cookies, session values, and unsanitized launch payloads.
  - [ ] Add a targeted browser smoke test only if ExUnit cannot credibly cover helper-page/postMessage behavior.
  - Command(s): `mix test test/oli_web/controllers/lti_controller_test.exs`
- Definition of Done:
  - Launch handling supports both legacy and storage-assisted resolution paths.
  - Recovery and terminal error outcomes are stable, sanitized, and explicitly classified.
  - Telemetry/logging is structured, useful, and privacy-safe.
- Gate:
  - User-visible error and recovery behavior must be stable before routing/data-model cleanup lands, so failures remain diagnosable during later refactors.
- Dependencies:
  - Phases 1 and 2.
- Parallelizable Work:
  - Telemetry implementation and template/copy work can proceed in parallel after the classification taxonomy is fixed.

## Phase 4: Replace Latest-Launch Routing with Validated Launch Context
- Goal: Ensure immediate post-launch routing and section resolution use the current validated launch context rather than user-global latest-launch lookups.
- Tasks:
  - [ ] Introduce `Oli.Lti.LaunchContext` normalization from validated claims with the fields required for immediate routing, section lookup, and service endpoint updates.
  - [ ] Update launch handling to pass `LaunchContext` through the authenticated redirect path and add an explicit redirect boundary in `delivery_web.ex` for launch-driven routing.
  - [ ] Remove runtime dependence on `get_latest_user_lti_params/1` from the LTI launch redirect flow and replace it with current-request context.
  - [ ] Audit existing persisted-launch consumers, preserving or adapting the paths that legitimately require stored context for admin observability or section-creation workflows.
  - [ ] Narrow durable `LtiParams` usage toward normalized context fields while preserving transitional compatibility for remaining support/admin consumers.
- Testing Tasks:
  - [ ] Add regression tests proving immediate launch redirect uses current validated context even when multiple persisted launch records exist for the same user.
  - [ ] Add tests covering section-resolution boundaries and tenant safety with the explicit launch context.
  - [ ] Add regression coverage proving `get_latest_user_lti_params/1` is not consulted during the launch redirect path.
  - Command(s): `mix test test/oli_web/controllers/lti_controller_test.exs`
- Definition of Done:
  - Immediate post-launch routing uses current validated context only.
  - Latest-launch lookup semantics are removed from the launch redirect path.
  - Persisted launch data remains sufficient for approved downstream consumers without regressing section creation or observability.
- Gate:
  - The hardened launch flow cannot be considered complete until stale-context routing risk is eliminated and test-covered.
- Dependencies:
  - Phases 1 and 3.
- Parallelizable Work:
  - LaunchContext normalization and persisted-consumer audit can run in parallel once the routing interface contract is defined.

## Phase 5: End-to-End Verification, Cleanup, and Rollout Readiness
- Goal: Verify the full work item against the requirements, close transitional gaps, and leave the feature ready for implementation handoff or release sequencing.
- Tasks:
  - [ ] Run the full targeted backend test suite for touched LTI, delivery, and persistence modules and fix any regressions.
  - [ ] Add or update migration/cleanup operational notes for launch-state TTL management and any deploy-order concerns.
  - [ ] Reconcile work item documentation if implementation decisions diverge from the PRD/FDD, especially around admin compatibility signaling or retained `params` payload shape.
  - [ ] Capture manual verification steps for at least one embedded storage-assisted launch and one blocked-cookie or blocked-storage recovery scenario.
  - [ ] Confirm no unresolved work-item placeholders remain in the work item artifacts.
- Testing Tasks:
  - [ ] Execute targeted automated verification for all touched modules plus any thin browser smoke coverage added in earlier phases.
  - [ ] Run requirements and work-item validation scripts required by the harness workflow.
  - Command(s): `mix test test/oli_web/controllers/lti_controller_test.exs`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/lti-launch-hardening --action verify_plan`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/lti-launch-hardening --action master_validate --stage plan_present`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/lti-launch-hardening --check plan`
- Definition of Done:
  - Phase-level verification is complete and documented.
  - Work item artifacts are synchronized with the chosen implementation path.
  - Harness validation passes for the plan stage.
- Gate:
  - Do not hand off for implementation until validation scripts pass and manual verification notes are captured.
- Dependencies:
  - Phases 1 through 4.
- Parallelizable Work:
  - Documentation reconciliation and manual verification note drafting can proceed while the final automated checks run.

## Parallelization Notes
- Phase 1 signed-state helper work and launch-state domain tests can proceed concurrently after the interface shape is fixed.
- In Phase 2, helper-page implementation is safe to parallelize with controller login-path refactoring once the request payload contract is settled.
- In Phase 3, telemetry wiring and recovery/error template work can proceed concurrently after the failure taxonomy is finalized.
- In Phase 4, the persisted-consumer audit can run alongside `LaunchContext` routing changes, but the final removal of latest-launch lookup dependence should wait for the audit outcome.
- Browser automation remains optional and thin; prioritize ExUnit/controller/domain coverage unless a real browser is required to prove the helper-page handshake.

## Phase Gate Summary
- Gate 1: Signed launch-state handling and the `lti_1p3` validation boundary are proven without session-only assumptions.
- Gate 2: Torus-owned dual-path login construction is stable and test-covered.
- Gate 3: Hardened launch handling renders deterministic recovery and stable sanitized error pages with privacy-safe telemetry.
- Gate 4: Immediate routing uses validated `LaunchContext`, not latest persisted launch blobs.
- Gate 5: Targeted tests and harness validation pass, and work item docs reflect the final implementation path.
