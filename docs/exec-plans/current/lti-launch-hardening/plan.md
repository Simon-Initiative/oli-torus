# LTI Launch Hardening - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/lti-launch-hardening/prd.md`
- FDD: `docs/exec-plans/current/lti-launch-hardening/fdd.md`

## Scope
Restructure the Torus LTI registration and launch lifecycle around explicit server-owned state boundaries, deterministic route contracts, and validated-launch-context routing. The work includes introducing a canonical launch-attempt model, separating registration onboarding from launch recovery, simplifying login initiation paths, hardening post-launch session continuity diagnostics, and removing immediate redirect dependence on historical persisted launch records.

## Clarifications & Default Assumptions
- The current branch already contains partial hardening work, but this plan treats that code as transitional rather than final architecture.
- `lti_1p3` remains the lower-level validation and protocol boundary; this plan does not replace the library wholesale.
- A persisted `LaunchAttempt` model is the preferred end state even if a signed-envelope layer remains during migration.
- Registration GET and POST must be independently functional in embedded LMS contexts and must not rely on cross-origin session continuity.
- Error pages are terminal states, not fallback navigation surfaces.
- Any required `lti_1p3` library changes may be implemented against `.vendor/lti_1p3` during development, but before the final Torus PR is submitted those changes must be merged and released upstream as `lti_1p3` `0.12.0`, and `mix.exs` must be restored to reference the Hex package directly.

## Acceptance Criteria Coverage
- Phase 2 covers `AC-001`, `AC-002`, and the state-authority portion of `AC-003` by establishing canonical launch-attempt ownership and launch validation against that boundary.
- Phase 3 covers `AC-008` and part of `AC-010` by moving immediate redirect behavior to current validated `LaunchContext`.
- Phase 4 covers the onboarding side effects of invalid registration and invalid deployment while preserving `AC-010` boundaries.
- Phase 5 covers the deterministic path-selection portion of `AC-003`.
- Phase 6 covers the successful-launch-to-landing diagnostic gap that currently obscures `AC-006` and `AC-007` classifications in practice.
- Phases 1, 5, and 7 together cover `AC-004`, `AC-005`, `AC-006`, `AC-007`, and `AC-009` through explicit classification, recovery/error contracts, and structured observability.

## Phase 1: Instrument and Freeze the Current Lifecycle
- Goal: Establish observability and a stable baseline before changing more behavior.
- Tasks:
  - [ ] Map the full current route graph for `/lti/login`, `/lti/launch`, `/lti/register_form`, `/lti/register`, and any helper/recovery routes.
  - [ ] Add or tighten structured telemetry around login initiation, launch validation start, launch validation success, launch failure classification, user session creation, and redirect target selection.
  - [ ] Separate current failures into three buckets in logs and code comments:
    - launch-state failures
    - registration/onboarding failures
    - post-auth redirect/session continuity failures
  - [ ] Document the exact state sources currently consulted in each route.
- Testing Tasks:
  - [ ] Add or update controller assertions for telemetry/log metadata without exposing sensitive payloads.
  - Command(s): `mix test test/oli_web/controllers/lti_controller_test.exs`
- Definition of Done:
  - The team can explain each observed launch failure in terms of an explicit lifecycle stage.
  - No further implementation work depends on undocumented state flow assumptions.
- Gate:
  - Do not expand recovery or registration behavior until the current lifecycle is instrumented and legible.
- Dependencies:
  - None.
- Parallelizable Work:
  - Route inventory and telemetry assertion work can proceed in parallel.

## Phase 2: Introduce Canonical LaunchAttempt State
- Goal: Make one server-owned launch-state source authoritative.
- Tasks:
  - [ ] Design and implement `LaunchAttempt` with explicit fields for state, nonce, issuer, client_id, deployment hint, target_link_uri, flow mode, request_id, status, and expiry.
  - [ ] Create the canonical launch attempt during `/lti/login`.
  - [ ] Resolve launch attempt by incoming state during `/lti/launch`.
  - [ ] Define deterministic lifecycle transitions: `pending`, `validated`, `consumed`, `failed`, `expired`.
  - [ ] Keep current signed/session state only as migration compatibility, not as the documented authority.
- Testing Tasks:
  - [ ] Add domain tests for creation, resolution, expiry, replay, and tamper/failure classification.
  - [ ] Add controller tests proving `/lti/launch` resolves from canonical launch attempt state.
  - Command(s): `mix test test/oli/lti`
  - Command(s): `mix test test/oli_web/controllers/lti_controller_test.exs`
- Definition of Done:
  - There is a single documented launch-state authority.
  - Launch failures can be explained in terms of launch-attempt lifecycle state.
- Gate:
  - Do not simplify route behavior until launch-state authority is singular.
- Dependencies:
  - Phase 1.
- Parallelizable Work:
  - Domain-model implementation and controller-adapter work can proceed in parallel once the schema/interface is fixed.

## Phase 3: Move Immediate Routing to Validated LaunchContext
- Goal: Eliminate stale-context redirect behavior.
- Tasks:
  - [ ] Normalize validated claims into a complete `LaunchContext`.
  - [ ] Route all successful immediate post-launch redirects from current-request `LaunchContext`.
  - [ ] Remove launch-path runtime dependence on `get_latest_user_lti_params/1`.
  - [ ] Audit remaining historical-launch consumers and classify them as:
    - keep for observability
    - migrate to normalized durable context
    - remove
- Testing Tasks:
  - [ ] Add regression coverage proving a user with multiple persisted launch records is routed by current validated launch only.
  - [ ] Add explicit tests proving the launch redirect path does not consult latest-user launch lookups.
  - Command(s): `mix test test/oli_web/controllers/lti_controller_test.exs`
- Definition of Done:
  - Successful launch redirect behavior is derived entirely from current validated claims.
- Gate:
  - Do not finalize launch hardening while stale-context routing remains possible.
- Dependencies:
  - Phase 2.
- Parallelizable Work:
  - Historical consumer audit can proceed while the redirect boundary is being refactored.

## Phase 4: Separate Registration Onboarding From Launch Recovery
- Goal: Make unknown registration/deployment handling independent from launch-session continuity.
- Tasks:
  - [ ] Define explicit onboarding inputs for invalid registration and invalid deployment flows.
  - [ ] Pass those inputs via explicit request params or a signed onboarding token.
  - [ ] Refactor `/lti/register_form` to depend only on explicit onboarding inputs.
  - [ ] Refactor `/lti/register` so pending-registration submission works without CSRF/session assumptions that break in LMS iframes.
  - [ ] Ensure registration errors remain registration errors and do not masquerade as launch failures.
- Testing Tasks:
  - [ ] Add controller tests for registration form render and registration submit in embedded/no-session conditions.
  - [ ] Add tests for invalid registration and invalid deployment onboarding transitions from `/lti/launch`.
  - Command(s): `mix test test/oli_web/controllers/lti_controller_test.exs`
- Definition of Done:
  - Registration works as a separate onboarding flow even when browser session continuity is weak.
- Gate:
  - Do not call the registration path “fixed” until both GET and POST work independently of embedded session continuity.
- Dependencies:
  - Phase 2.
- Parallelizable Work:
  - Registration UI cleanup and controller contract refactoring can proceed in parallel once onboarding transport is chosen.

## Phase 5: Simplify Login Initiation Paths
- Goal: Reduce overlapping flow logic to one chosen launch path per request.
- Tasks:
  - [ ] Define the exact flow-selection contract for:
    - legacy path
    - storage-assisted helper path
  - [ ] Ensure `/lti/login` chooses exactly one path and records that choice on the launch attempt.
  - [ ] Constrain helper-page logic to initiation/storage assistance only.
  - [ ] Remove recovery or registration responsibilities from helper-page code.
- Testing Tasks:
  - [ ] Add controller tests for path selection and helper behavior.
  - [ ] Add negative tests for unsupported or malformed storage-capability combinations.
  - Command(s): `mix test test/oli_web/controllers/lti_controller_test.exs`
- Definition of Done:
  - `/lti/login` has a deterministic flow choice and a narrow helper contract.
- Gate:
  - Do not finalize the launch contract while helper logic still owns unrelated state transport concerns.
- Dependencies:
  - Phases 2 and 4.
- Parallelizable Work:
  - Helper-page implementation and controller path-selection tests can run in parallel.

## Phase 6: Harden Successful Launch to Authenticated Landing
- Goal: Distinguish launch validation success from post-auth session continuity failure.
- Tasks:
  - [ ] Instrument and verify the path from valid `/lti/launch` to user session creation to next redirect request.
  - [ ] Add explicit classification for post-auth redirect/session continuity failure if launch validation and session creation succeed but the redirected request is unauthenticated.
  - [ ] Evaluate whether a signed post-launch handoff route is needed to decouple authenticated landing from immediate cookie replay assumptions.
  - [ ] Ensure the final learner/instructor landing path is observable and diagnosable.
- Testing Tasks:
  - [ ] Add controller or scenario coverage for successful launch followed by authenticated landing.
  - [ ] Add coverage for classified post-auth landing failure if the implementation introduces that classification.
  - Command(s): `mix test test/oli_web/controllers/lti_controller_test.exs`
- Definition of Done:
  - The system can distinguish “launch failed” from “launch succeeded but authenticated landing failed.”
- Gate:
  - Do not close the work item while successful launch and authenticated landing are still conflated.
- Dependencies:
  - Phases 2, 3, and 5.
- Parallelizable Work:
  - Observability work and handoff-route design can proceed in parallel until the final implementation choice is made.

## Phase 7: Remove Transitional Complexity and Reconcile Docs
- Goal: Make the final launch lifecycle the only documented and supported model.
- Tasks:
  - [ ] Remove obsolete session-only assumptions and dead compatibility branches that are no longer needed.
  - [ ] Merge any required `.vendor/lti_1p3` changes upstream, release `lti_1p3` `0.12.0`, and restore `mix.exs` to use the Hex dependency before final PR submission.
  - [ ] Reconcile `prd.md`, `fdd.md`, `plan.md`, and any LTI implementation docs with the final route and state model.
  - [ ] Capture manual verification notes for:
    - successful embedded launch
    - invalid registration onboarding
    - blocked-cookie or blocked-storage launch
    - successful launch to authenticated landing
    - final dependency state using released `lti_1p3` rather than the local `.vendor` path
  - [ ] Close remaining follow-ups about historical launch payload consumers.
- Testing Tasks:
  - [ ] Run targeted LTI controller/domain suites for final verification.
  - [ ] Run targeted verification after dependency normalization away from `.vendor/lti_1p3`.
  - [ ] Run work-item validation scripts.
  - Command(s): `mix test test/oli_web/controllers/lti_controller_test.exs`
  - Command(s): `mix test test/oli/lti`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/lti-launch-hardening --action verify_plan`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/lti-launch-hardening --action master_validate --stage plan_present`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/lti-launch-hardening --check plan`
- Definition of Done:
  - The code and docs describe one launch lifecycle rather than a set of layered exceptions.
- Gate:
  - Final handoff requires doc reconciliation and validation, not just passing tests.
- Dependencies:
  - Phases 1 through 6.
- Parallelizable Work:
  - Documentation reconciliation and manual verification note drafting can proceed while final test/validation runs execute.

## Parallelization Notes
- LaunchAttempt modeling and route/contract inventory can progress in parallel once instrumentation is in place.
- Historical launch-consumer audit can run alongside LaunchContext redirect refactoring.
- Registration onboarding transport design can proceed in parallel with helper-path simplification because those concerns should become independent.
- Post-auth landing diagnostics can begin once successful-launch observability is available, even before the final handoff design is chosen.

## Phase Gate Summary
- Gate A: The current lifecycle is instrumented and failures are attributed to explicit stages.
- Gate B: LaunchAttempt is the canonical launch-state source.
- Gate C: Immediate redirect uses validated LaunchContext only.
- Gate D: Registration is independent from launch-session continuity.
- Gate E: `/lti/login` selects one deterministic path per request.
- Gate F: Successful launch can be distinguished from failed authenticated landing.
- Gate G: Transitional complexity is removed, dependency state is normalized back to released Hex packages, and docs match the final design.
