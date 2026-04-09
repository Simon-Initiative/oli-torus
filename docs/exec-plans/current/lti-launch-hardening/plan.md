# LTI Launch Hardening - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/lti-launch-hardening/prd.md`
- FDD: `docs/exec-plans/current/lti-launch-hardening/fdd.md`

## Scope

Implement the LTI launch lifecycle hardening described in the PRD and FDD by keeping `/lti/login` and `/lti/launch` on a single session-backed path, removing immediate redirect dependence on `get_latest_user_lti_params/1`, simplifying invalid registration and invalid deployment handoff to `/lti/register_form`, and improving launch telemetry, logging, terminal error rendering, and iframe-safe registration behavior. The archived storage-assisted prototype is retained only as a documented checkpoint and is not part of the final supported design.

## Clarifications & Default Assumptions

- The authoritative work-item artifacts are [prd.md](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/lti-launch-hardening/prd.md) and [fdd.md](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/lti-launch-hardening/fdd.md).
- The registration-request handoff remains on `GET /lti/register_form` and uses explicit URL parameters for first render, then posted form values for invalid submit re-rendering.
- The final supported design keeps session-backed launch state in Phoenix session and does not retain `launch_attempts`, storage-assisted helper behavior, or post-launch continuation fallback behavior.
- `get_latest_user_lti_params/1` is no longer allowed in the immediate `/lti/launch` success path, but remains an accepted fallback for authenticated non-launch redirects where no current-launch handoff exists.
- For instructor-capable non-launch fallback redirects, a missing active section for the current LTI context should resolve to the section setup flow rather than the generic unavailable-section page.
- Telemetry, logging, and issue-tracker follow-through must be planned explicitly because `harness.yml` marks observability and issue tracking as adopted defaults.
- During implementation, task checkboxes in this plan should be updated as work is completed so phase status remains accurate.

## Phase 1: Launch Attempt Foundation

- Goal: Establish the canonical shared launch-attempt boundary and the minimal infrastructure needed to classify launch lifecycle state across app nodes.
- Tasks:
  - [x] Add the `lti_launch_attempts` schema, migration, indexes, and changesets described in the FDD.
  - [x] Implement `Oli.Lti.LaunchAttempts` with create, resolve, transition, expiry, and cleanup-selection functions.
  - [x] Add an Oban cleanup worker or equivalent scheduled job for expired active or unconsumed launch attempts.
  - [x] Define stable lifecycle-state, flow-mode, transport-method, and failure-classification enums/constants in one backend boundary.
  - [x] Add unit-level logging and telemetry hooks for attempt creation, transition, expiry, and cleanup outcomes.
- Testing Tasks:
  - [x] Add ExUnit coverage for schema validation, expiry behavior, atomic transitions, and cleanup eligibility.
  - [x] Add ExUnit coverage proving attempts are shareable by key and do not depend on node-local session authority.
  - [x] Run targeted backend tests for the new domain module and worker.
  - Command(s): `mix test test/oli/lti`, `mix format`
- Definition of Done:
  - The application can create, resolve, transition, and expire launch attempts through a single domain API.
  - Cleanup behavior exists for expired active or unconsumed attempts.
  - Shared launch-attempt storage is database-backed and traceable to `FR-002`, `FR-015`, `FR-003`, `AC-002`, `AC-003`, `AC-011`, and `AC-014`.
- Gate:
  - No controller flow changes begin until the launch-attempt data model, transitions, and cleanup behavior are tested and stable.
- Dependencies:
  - None.
- Parallelizable Work:
  - Migration/schema work and cleanup-worker implementation can proceed in parallel once the state model is agreed.

## Phase 2: Login And Launch Path Refactor

- Goal: Move `/lti/login` and `/lti/launch` to the launch-attempt authority, select storage-assisted versus legacy flow correctly, and classify failures deterministically.
- Tasks:
  - [x] Refactor `OliWeb.LtiController` so `/lti/login` creates a `launch_attempt` and chooses `lti_storage_target` or `session_storage` from LMS capability signaling and the storage-target feature flag.
  - [x] Keep the legacy session-backed flow only for LMSs that do not advertise `lti_storage_target`.
  - [x] Implement storage-assisted continuation behavior and any required intermediate helper response/page.
  - [x] Refactor `/lti/launch` to resolve the canonical attempt, validate through `lti_1p3`, and apply stable failure classifications.
  - [x] Remove Phoenix-session launch-state authority outside the explicit legacy fallback requirements.
  - [x] Render stable Torus-owned launch errors for missing, mismatched, expired, consumed, validation, storage-blocked, handler, and post-auth failures.
  - [x] Add keyset and `kid` diagnostic instrumentation at validation boundaries.
- Testing Tasks:
  - [x] Add controller tests for storage-assisted path selection, feature-flag-controlled storage fallback, and legacy fallback behavior.
  - [x] Add controller tests for invalid registration, invalid deployment, missing state, mismatched state, expired state, consumed state, validation failure, storage-blocked failure, launch-handler failure, and post-auth landing failure.
  - [x] Add targeted tests for keyset and `kid` diagnostic logging where practical.
  - [x] Run the affected LTI controller test modules.
  - Command(s): `mix test test/oli_web/controllers`, `mix format`
- Definition of Done:
  - `/lti/login` and `/lti/launch` are driven by the canonical launch attempt.
  - Storage-assisted launches run only when advertised, and non-supporting LMSs keep the legacy path.
  - Terminal launch failures are explicitly classified and rendered through Torus-owned outcomes.
  - Path selection and failure handling satisfy `AC-001`, `AC-006`, and `AC-010`.
- Gate:
  - Do not remove stale redirect dependencies or adjust registration handoff until login and launch path selection plus failure classification are verified.
- Dependencies:
  - Phase 1.
- Parallelizable Work:
  - Storage-assisted helper work and failure-template refinement can proceed in parallel after the controller contract is set.

## Phase 3: Redirect Authority And Registration Handoff

- Goal: Make immediate post-launch routing depend only on the current validated launch, add a controlled landing fallback for embedded-session loss, and replace session-based registration handoff with explicit request context.
- Tasks:
  - [x] Add a current-launch-based redirect entrypoint and wire launch success to it.
  - [x] Add a signed post-launch landing route that can detect whether the embedded Torus session survived before entering protected delivery.
  - [x] Add feature-flag-controlled fallback behavior so embedded-session loss after a successful launch either renders a new-window recovery page or a terminal privacy error.
  - [x] Remove or deprecate `get_latest_user_lti_params/1` from the immediate launch redirect path.
  - [x] Persist only the routing fields needed on `launch_attempt` to resolve the correct destination from the current launch.
  - [x] Change invalid registration and invalid deployment handling to redirect to `/lti/register_form` with explicit `issuer`, `client_id`, and optional `deployment_id` URL parameters.
  - [x] Update `/lti/register_form` and registration-request handling so first render uses URL parameters and invalid submit re-renders from posted form values.
  - [x] Confirm the same registration template is used for invalid registration and invalid deployment outcomes.
- Testing Tasks:
  - [x] Add ExUnit coverage proving immediate redirect no longer consults `get_latest_user_lti_params/1`.
  - [x] Add controller coverage for landing continuation, new-window fallback rendering, terminal privacy-error rendering, and current-state redirect resolution from the landing path.
  - [x] Add controller or LiveView coverage for registration-form initial render from URL parameters and invalid-submit re-render from posted values.
  - [x] Add regression tests proving refresh reconstruction is not required for the single-use handoff.
  - [x] Run targeted redirect and registration test modules.
  - Command(s): `mix test test/oli_web`, `mix format`
- Definition of Done:
  - Immediate launch redirect uses only current validated launch context.
  - Invalid registration and invalid deployment use the same registration-form surface without Phoenix-session handoff.
  - Traceability is satisfied for `FR-004`, `FR-005`, `FR-006`, `FR-016`, `FR-017`, `AC-004`, `AC-005`, `AC-012`, and `AC-013`.
- Gate:
  - No final observability signoff until redirect authority and registration handoff are proven not to rely on latest-user or session-carried launch context.
- Dependencies:
  - Phase 2.
- Parallelizable Work:
  - Redirect refactor and registration-form parameter work can proceed in parallel after the successful-launch payload contract is defined.

## Phase 4: Observability, Upstream Integration, And Hardening

- Goal: Finish operational visibility, remove dependency drift, and verify the full lifecycle against the spec pack.
- Tasks:
  - [x] Standardize structured logs and telemetry names for attempt creation, path selection, transport method, validation, classification, redirect resolution, registration handoff, and cleanup.
  - [x] Ensure every successful and failed launch emits `transport_method` as `lti_storage_target` or `session_storage`.
  - [x] Verify sanitized user-facing error rendering and non-sensitive logging payloads.
  - [x] Harden terminal LTI error rendering so launch errors remain stable and do not escalate into follow-up LiveView reconnect 404s or frontend bootstrap failures.
  - [x] Make the LTI registration form iframe-safe by removing CSRF/session dependence from the embedded registration endpoints and fixing null-safe client-side prepopulation behavior.
  - [N/A] Confirm any temporary `.vendor/lti_1p3` changes are merged upstream, released as `0.12.0`, and Torus is restored to the Hex dependency.
  - [x] Update implementation-facing docs if behavior or rollout guidance changed materially during coding.
  - [N/A] Capture Jira follow-through and rollout notes required by repository issue-tracking practice.
- Testing Tasks:
  - [x] Add or finalize telemetry/log assertions for success and failure paths, including transport method.
  - [x] Add regression coverage for stable LTI error rendering and iframe-safe registration behavior.
  - [x] Run targeted LTI suites plus any broader regression modules warranted by risk.
  - [x] Run compile and formatting gates for the touched backend and frontend surfaces.
  - Command(s): `mix test test/oli/lti test/oli_web/controllers`, `mix compile`, `mix format`
- Definition of Done:
  - Observability covers launch path, lifecycle stage, stable classification, transport method, and keyset diagnostics without leaking sensitive data.
  - The repository no longer depends on a vendored `lti_1p3`.
  - The implementation is ready for `harness-develop` phase execution and final review against the work item.
  - Completion criteria explicitly satisfy `AC-007`, `AC-015`, `AC-008`, and `AC-009`.
- Gate:
  - Final implementation signoff requires green targeted tests, Hex-restored `lti_1p3 0.12.0`, and spec-pack traceability intact.
- Dependencies:
  - Phases 1 through 3.
- Parallelizable Work:
  - Telemetry assertion coverage and upstream dependency restoration can overlap once behavior is stable, but final merge must wait for both.

## Parallelization Notes

- Phase 1 schema and cleanup work can be split safely if both use the same lifecycle-state contract.
- In Phase 2, storage-assisted helper mechanics and failure-template work are parallel-safe after the controller request and response contract is defined.
- In Phase 3, redirect refactor and registration-form handoff updates are parallel-safe once the successful-launch payload and registration URL contract are fixed.
- Phase 4 upstream `lti_1p3` release work may proceed in parallel with telemetry finishing work, but the final Torus PR cannot merge until both are complete.
- Keep controller transport logic thin and move reusable lifecycle rules into `Oli.Lti.LaunchAttempts` to limit merge risk across phases.

## Phase Gate Summary

- Gate A: launch-attempt schema, transitions, and cleanup must be implemented and tested before controller refactors start.
- Gate B: `/lti/login` and `/lti/launch` must be attempt-driven, with correct storage-assisted versus legacy selection and stable failure classification.
- Gate C: immediate redirect must no longer depend on `get_latest_user_lti_params/1`, and registration handoff must be explicit and session-independent.
- Gate D: observability must be complete, transport method must be logged on success and failure, and any temporary vendored `lti_1p3` changes must be upstreamed and replaced with Hex `0.12.0`.

## Phase 5: Remove Storage-Assisted Launch Support

- Goal: Remove cookie-less launch support and its rollout controls while preserving the launch-hardening, redirect, telemetry, error-handling, and registration improvements delivered by the earlier phases.
- Reference: the archived prototype state for the removed design is recorded in [prototype-checkpoint.md](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/lti-launch-hardening/prototype-checkpoint.md).
- Tasks:
  - [x] Remove `lti_storage_target` transport selection and make `/lti/login` always use `session_storage`.
  - [x] Remove the storage-assisted helper page and any browser-side storage orchestration used only for that path.
  - [x] Remove the post-launch continuation fallback behavior and any signed landing continuation logic used only to support the partial cookieless flow.
  - [x] Remove the `Oli.Lti.LaunchAttempt` schema, `Oli.Lti.LaunchAttempts` domain API, migration-backed launch-attempt storage, and cleanup jobs introduced for that design.
  - [x] Remove the `lti-storage-target` feature flag and the `lti-new-tab-fallback` feature flag.
  - [x] Keep the stable launch classification, redirect improvements, registration-request handoff, telemetry, and iframe-related fixes intact without depending on persisted launch-attempt state.
  - [x] Keep the `lti.html.heex` layout hardening that removes the tech support modal `live_render` so terminal LTI error pages do not trigger unintended LiveView reconnect and 404 behavior.
  - [x] Keep the embedded missing-state browser-privacy error and LMS-admin guidance that tells institutions to configure Torus to open in a new window when iframe launch state is blocked.
  - [x] Reconcile PRD, FDD, plan, and implementation notes so the feature is documented as session-backed launch hardening rather than storage-assisted launch support or launch-attempt persistence.
- Testing Tasks:
  - [x] Remove or rewrite controller tests that exist only for storage-assisted helper, continuation fallback, launch-attempt persistence, and cleanup behavior.
  - [x] Keep and update controller tests for session-backed login and launch behavior, non-stale redirect behavior, stable error handling, and registration-form handoff.
  - [x] Run targeted LTI, redirect, and registration test modules after the storage-assisted path and launch-attempt persistence are removed.
  - [x] Run compile and formatting gates for the touched backend and frontend surfaces.
  - Command(s): `mix test test/oli/lti test/oli_web/controllers`, `mix compile`, `mix format`
- Definition of Done:
  - Torus no longer contains storage-assisted launch behavior, continuation fallback behavior, persisted launch-attempt state, cleanup jobs, or rollout flags that exist only for those paths.
  - Session-backed launch retains the hardening improvements from Phases 1 through 4 that do not depend on storage-assisted launch or launch-attempt persistence.
  - Documentation and tests describe the resulting session-backed design accurately.
- Gate:
  - Final signoff requires green targeted tests and documentation reconciled to the de-scoped design.
- Dependencies:
  - Phases 1 through 4.
- Parallelizable Work:
  - Code removal and documentation reconciliation can proceed in parallel once the retained behavior set is fixed.
