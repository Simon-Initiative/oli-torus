# LTI Launch Hardening - Product Requirements Document

## 1. Overview

Harden the Torus LTI 1.3 launch lifecycle while keeping the supported design session-backed. The work should make launch routing deterministic from the current validated launch, separate launch and onboarding concerns, improve telemetry plus stable user-facing error handling, and preserve a clear browser-privacy failure message when embedded launches cannot complete because iframe cookie or session continuity is blocked.

## 2. Background & Problem Statement

Torus currently relies on browser-managed session continuity between `/lti/login`, registration-related handling, and `/lti/launch`. In embedded LMS contexts, browser privacy controls can block or degrade third-party and iframe cookie behavior, which causes intermittent launch failures, onboarding context loss, and ambiguous recovery behavior. The present design also allows immediate post-launch routing to depend on user-global historical launch state rather than only on the current validated launch, which makes routing less precise and harder to diagnose.

Implementation work on this branch clarified an architectural limit: even when the LTI state handshake is made more resilient, Torus delivery still depends deeply on its own authenticated web session model after launch. Because Torus cannot provide a reliable cookieless embedded experience without a much larger authentication redesign, the supported direction is to keep a single session-backed launch path and preserve the hardening work that remains valuable in that shape: deterministic redirect behavior from the current validated launch, explicit registration-request handoff, stable terminal error handling, iframe-safe registration behavior, and better operational visibility.

## 3. Goals & Non-Goals

### Goals

- Keep `/lti/login` and `/lti/launch` on a single supported session-backed launch path.
- Ensure immediate post-launch routing uses only the current validated launch context.
- Eliminate use of `get_latest_user_lti_params/1` in the immediate launch redirect path while allowing it to remain as a fallback for non-launch authenticated redirects.
- Technically decouple registration onboarding from launch-state transport assumptions while preserving required onboarding outcomes.
- Use explicit URL parameters such as `issuer`, `client_id`, and `deployment_id` to hand off into the admin registration-request form when registration or deployment cannot be found, rather than relying on Phoenix session state.
- Classify launch lifecycle failures into stable, explicit categories with durable user-facing outcomes.
- Improve logging and telemetry so support and engineering can diagnose launch path selection, validation outcomes, state failures, and handler failures without exposing sensitive payloads.
- Explicitly log and emit telemetry for the launch-state transport method used on every successful and failed launch, using the stable value `session_storage`.
- Fix embedded launch terminal pages so they remain stable and do not escalate into unrelated LiveView reconnects, 404s, or frontend JavaScript crashes.
- Make the LTI registration form usable in iframe contexts without depending on Phoenix CSRF session continuity for the registration endpoints.
- Preserve `lti_1p3` as the lower-level protocol and validation layer without introducing a Torus-owned alternate launch transport.

### Non-Goals

- Redesign broad LMS administration UX beyond the launch and onboarding changes required by this work.
- Replace `lti_1p3` with a Torus-specific protocol implementation.
- Redesign unrelated learner or instructor post-launch product surfaces.
- Build a broad browser compatibility support matrix UI beyond the diagnostics and recovery behavior needed for launch reliability.
- Solve every historical LMS integration issue that is not part of launch-state transport, launch routing, onboarding decoupling, or lifecycle observability.
- Deliver a supported cookieless or storage-assisted embedded delivery experience.

## 4. Users & Use Cases

- Students: launch Torus from an embedded LMS placement and land in the correct course destination even when cross-site cookie continuity is unavailable.
- Instructors: launch instructor-facing Torus placements reliably and receive clear, stable failure guidance when browser or LMS conditions prevent completion.
- Institution and LMS administrators: distinguish invalid registration or deployment issues from browser-state or storage limitations without ambiguous sign-in or 404 outcomes.
- Support and operations staff: inspect telemetry and logs to determine which launch path ran, where the lifecycle failed, and whether the failure was caused by state transport, validation, onboarding, or landing behavior.
- Engineers maintaining LTI support: evolve launch behavior while preserving a clean boundary with `lti_1p3` and a deployment-safe multi-node architecture.

## 5. UX / UI Requirements

- Launch failures must render stable Torus-owned error states that remain visible and readable instead of redirecting to unrelated sign-in, 404, or generic failure pages.
- User-facing launch error copy must be sanitized and must explain the failure category and next step in plain language without exposing raw launch claims, tokens, cookies, session values, stack traces, or registration secrets.
- Error states must distinguish likely browser or storage problems from invalid LMS registration or deployment problems.
- Onboarding-related failures must be presented as onboarding outcomes, not as generic launch-validation failures.
- Recovery guidance for blocked browser storage must remain generic and actionable, including instructing the user to allow cookies when appropriate or contact their LMS administrator if the tool must be launched in a top-level tab.
- The LTI error page must remain a static terminal surface and must not mount nested LiveView behavior that can trigger follow-up requests to invalid routes.
- The registration form must render and submit inside an LMS iframe without crashing on missing optional prepopulation data.

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)

Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Reliability: the session-backed launch flow must classify missing, mismatched, storage-blocked, validation, and handler failures deterministically.
- Security: the redesigned lifecycle must preserve CSRF, nonce, replay-protection, registration-validation, and deployment-validation guarantees.
- Privacy: logs and telemetry must exclude raw id tokens, cookies, session contents, login hints, registration secrets, and other sensitive launch payloads.
- Maintainability: launch-state creation, validation, classification, and immediate routing must have a documented single authority rather than multiple overlapping state sources.
- Accessibility: any intermediate launch page, recovery page, or error state introduced by this work must remain keyboard accessible and screen-reader understandable.
- Performance: the hardened session-backed flow and telemetry must not materially regress launch latency for successful launches.
- Compatibility: immediate launch redirect behavior must resolve against current section state rather than stale latest-user launch snapshots.

## 9. Data, Interfaces & Dependencies

- The work affects `/lti/login`, `/lti/launch`, and `/lti/register_form`.
- Immediate launch routing must consume the current validated launch claims and must not depend on `get_latest_user_lti_params/1` or equivalent user-global latest-launch lookups.
- Non-launch authenticated redirect entrypoints may continue to use `get_latest_user_lti_params/1` as a fallback when no current-launch handoff is in progress.
- The registration-request form for invalid registration or invalid deployment must load its initial rendered values from explicit URL parameters such as `issuer`, `client_id`, and `deployment_id` rather than from Phoenix session state.
- Invalid registration and invalid deployment handoff should be treated as a single-use render path rather than a long-lived refreshable state; after the initial render, form resubmission handling should rely on submitted form values instead of rereading launch handoff state.
- The implementation continues to depend on `lti_1p3` for lower-level validation and protocol enforcement.
- Telemetry and logging should include launch path, launch-state transport method, lifecycle stage, failure classification, and keyset lookup diagnostics using non-sensitive metadata only.

## 10. Repository & Platform Considerations

- Torus is a Phoenix application with focused React surfaces, so core launch lifecycle decisions must remain on the server boundary in `lib/oli/` and `lib/oli_web/`.
- The implementation should respect existing LTI boundaries and keep `lti_1p3` as the lower-level validation layer instead of spreading protocol rules through controller or frontend-only code.
- Verification should emphasize targeted ExUnit coverage for launch classification, routing behavior, onboarding decoupling, stable error rendering, and iframe-safe registration behavior.
- Operational behavior should align with existing AppSignal, logging, and telemetry practices documented for the repository.
- Jira is the system of record for feature execution tracking in this repository and should be used for implementation follow-through once planning is approved.

## 11. Feature Flagging, Rollout & Migration

- No feature flags are required for the final supported design.
- The archived storage-assisted prototype is retained only as a documented checkpoint in [prototype-checkpoint.md](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/lti-launch-hardening/prototype-checkpoint.md).

## 12. Telemetry & Success Metrics

- Emit structured telemetry and logs for launch path selection, launch validation outcome, redirect resolution, registration handoff, and terminal failure classification.
- Emit structured telemetry and logs for the launch-state transport method used on every successful and failed launch, with the stable value `session_storage`.
- Emit structured diagnostics for keyset lookup and `kid` resolution failures, including lookup source, requested `kid`, cached key identifiers, cache freshness context when available, and terminal classification without leaking token payloads.
- Emit separate classifications for launch failure and onboarding failure so production issues can be attributed to the correct lifecycle stage.
- Success signal: immediate redirect behavior no longer consults `get_latest_user_lti_params/1`.
- Success signal: any remaining `get_latest_user_lti_params/1` usage is limited to explicit non-launch fallback redirects rather than the immediate `/lti/launch` success path.
- Success signal: launch failures consistently render stable classified error pages rather than sign-in redirects or unrelated 404 outcomes.
- Success signal: support can identify the launch path and stable failure category from logs and telemetry in the majority of production incidents.
- Success signal: support and QA can determine from logs and telemetry that launches used the supported `session_storage` path in both success and failure cases.

## 13. Risks & Mitigations

- Browser privacy settings can still block embedded session continuity for some launches: retain a stable browser-privacy error and explicit LMS-admin guidance to configure Torus to open in a new window.
- Registration-request handoff may uncover hidden dependencies on session or CSRF assumptions: load the initial registration form from explicit URL parameters on a normal GET route, treat the handoff as single-use, and test invalid-submit re-rendering from posted form values separately from launch validation.
- Better user-facing errors could accidentally expose sensitive internals: define a sanitized error taxonomy and keep detailed diagnostics only in protected logs and telemetry.
- Shared layouts can accidentally mount interactive behavior on terminal launch pages: keep LTI error surfaces static and test against follow-up reconnect or 404 regressions.
- Additional telemetry can become noisy or incomplete if event boundaries are not designed carefully: standardize lifecycle stage names, failure categories, and correlation identifiers before implementation.

## 14. Open Questions & Assumptions

### Open Questions

- Which currently supported LMS platforms used by Torus customers already advertise and successfully
  exercise the storage-assisted embedded launch capability?
  Canvas, Blackboard, and Brightspace appear to advertise and support the storage-assisted embedded
  launch capability. Moodle does not appear to advertise this capability. LMSs that do not support
  this capability will continue to rely on the legacy cookie or session-based launch path, which may
  remain more prone to embedded launch failures but does not regress existing behavior.
- Does a successful storage-assisted launch eliminate Torus’s own browser-session dependence for embedded delivery?
  No. Implementation validated that Torus delivery remains dependent on its authenticated web session
  after launch. Storage-assisted launch transport improves the LTI handshake boundary, but it does
  not by itself make the broader Torus delivery surface cookieless.
- Should invalid registration and invalid deployment resolve to the same terminal user-facing
  template with different support metadata, or separate user-facing variants?
  Same terminal template. This should show the institution registration form.
- What exact persisted launch-context fields still need to remain durable after immediate
  post-launch routing is changed to use only the current validated launch?
  Long-lived business state should continue to live in user, enrollment, and section records rather
  than in a user-global latest-launch record. The launch-attempt row should persist the routing
  context needed to derive the correct destination from the current launch, including at minimum
  `issuer`, `client_id`, `deployment_id`, `context_id`, `resource_link_id`, `message_type`,
  `target_link_uri`, and roles, plus `resolved_section_id` once Torus maps the launch to a section.
  Immediate redirect behavior should use those current-launch fields rather than session state or
  `get_latest_user_lti_params/1`.

### Assumptions

- Browser privacy restrictions on cross-site and iframe cookies are a material cause of current intermittent embedded launch failures.
- Torus can introduce a database-backed launch-attempt boundary that works across clustered deployments without redesigning unrelated authentication infrastructure.
- Standards-aligned storage-assisted launch behavior can coexist with the existing `lti_1p3` validation layer.
- Storage-assisted launch transport and post-launch new-tab recovery need separate feature flags because they control different rollout risks.
- When an LMS does not advertise `lti_storage_target`, the existing cookie or session-based launch path remains the correct fallback behavior.
- Invalid registration and invalid deployment should resolve to the same user-facing registration-request form experience.
- The admin registration-request flow for invalid registration or deployment can use explicit URL parameters for the initial render rather than Phoenix session state or a separate onboarding-context artifact.
- Invalid registration and invalid deployment handoff is single-use and does not need to support page refresh or long-term persistence after the initial form render.
- Existing observability tooling can absorb the new lifecycle telemetry and log events without requiring a separate platform project.

## 15. QA Plan

- Automated validation:
  - ExUnit coverage for `/lti/login` and `/lti/launch` launch-attempt creation, resolution, expiration, consumption, and deterministic failure classification.
  - Coverage confirming Torus chooses the storage-assisted path only when `lti_storage_target` is advertised and otherwise uses the existing cookie or session-based path.
  - Coverage confirming Torus uses `session_storage` even when `lti_storage_target` is advertised if the `lti-storage-target` feature flag is disabled.
  - Regression tests confirming immediate post-launch routing uses only the current validated launch context and no longer consults `get_latest_user_lti_params/1`.
  - Coverage for the post-launch landing boundary where a valid successful launch:
    - continues normally when the Torus session survived,
    - offers “Continue in a new tab” when enabled and the embedded session is unavailable,
    - renders the embedded-browser privacy error when the new-tab fallback feature is disabled.
  - Regression coverage proving fallback continuation resolves against current section state rather than a stale destination captured when the fallback page was first rendered.
  - Coverage for invalid registration, invalid deployment, missing state, mismatched state, consumed state, storage-blocked, validation failure, launch-handler failure, and post-auth landing failure classifications.
  - Tests for registration-request handoff where `/lti/register_form` loads issuer, client ID, and deployment values from explicit URL parameters rather than session continuity.
  - Tests confirming invalid registration or invalid deployment handoff is single-use and that invalid form-submit re-rendering relies on submitted form values rather than rereading launch handoff state.
  - Tests for launch-attempt cleanup behavior driven by `expires_at` for active or unconsumed attempts.
  - Targeted coverage for any browser-side storage-assisted helper or intermediate page introduced by the redesign.
  - Regression tests for stable LTI error rendering so terminal error pages do not escalate into LiveView reconnect 404s or frontend bootstrap crashes.
- Manual validation:
  - Exercise an embedded LMS launch that advertises storage-assisted capability and confirm the launch succeeds without relying solely on Phoenix session continuity.
  - Exercise a legacy launch path in a compatible browser and confirm existing successful behavior remains intact.
  - Trigger representative failure categories and confirm the user sees a stable, sanitized, correctly classified Torus error state rather than a sign-in or 404 redirect.
  - Exercise a successful launch in an iframe where the first Torus session does not survive and confirm the landing behavior matches the active feature-flag configuration.
  - Verify the registration form can render and submit inside an LMS iframe without CSRF rejection or client-side prepopulation crashes.
  - Verify telemetry and logs identify launch path, lifecycle stage, and failure category without leaking sensitive payloads.
  - Verify any temporary `.vendor/lti_1p3` implementation changes are replaced by the released Hex dependency before final merge.

## 16. Definition of Done

- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes

## 17. Follow-On: Remove Storage-Assisted Launch Support

### Decision

The branch proves that Torus can complete a storage-assisted LTI handshake, but it also confirms that Torus delivery remains fundamentally dependent on its own authenticated web-session model after launch. Given the security tradeoffs of the continuation design and the overall complexity of maintaining a partial cookieless experience, the follow-on direction is to remove storage-assisted launch support from Torus while keeping the broader launch-hardening work.

The archival prototype checkpoint for this design is recorded in [prototype-checkpoint.md](/Users/eliknebel/Developer/oli-torus/docs/exec-plans/current/lti-launch-hardening/prototype-checkpoint.md).

### Follow-On Goals

- Remove `lti_storage_target` handling from the Torus login and launch flow.
- Remove the storage-assisted helper page and all browser-side storage-assisted orchestration.
- Remove the database-backed `launch_attempts` model, the `Oli.Lti.LaunchAttempts` domain API, and related cleanup jobs.
- Remove the `lti-storage-target` feature flag and the `lti-new-tab-fallback` feature flag.
- Remove the post-launch continuation fallback page and signed landing continuation behavior that exists only to support the partial cookieless flow.
- Keep the stable error handling, deterministic redirect behavior, telemetry improvements, registration-form fixes, and iframe-safe registration handoff.
- Keep the LTI layout hardening that removes the tech support modal `live_render` from `lti.html.heex`, so terminal LTI error pages do not trigger unintended LiveView reconnects and follow-up 404 redirects.
- Keep the browser-privacy launch failure experience for embedded missing-state cases, including the user-facing error and guidance that the LMS administrator should configure Torus to open in a new window.
- Keep the legacy session-backed LTI launch path as the only supported launch transport.

### Follow-On Non-Goals

- Preserve the stronger redirect authority by allowing launch-time validated params to drive immediate redirect behavior without reintroducing stale latest-user routing.
- Reintroduce session-backed stale redirect authority through `get_latest_user_lti_params/1` into the immediate `/lti/launch` success path.
- Remove the stable error rendering and logging improvements that were added as part of this branch.
- Revert the redirect hardening, telemetry work, or registration-request improvements that remain valuable without storage-assisted launch support.

### Follow-On Acceptance Direction

- `/lti/login` always selects `session_storage`.
- `/lti/launch` continues to provide stable classification and improved redirect behavior without depending on a persisted launch-attempt authority.
- The codebase no longer contains storage-assisted helper behavior, post-launch continuation fallback behavior, persisted launch-attempt state, cleanup jobs, or feature flags that exist only to control those behaviors.
- Existing hardening improvements remain in place and verified after the storage-assisted path is removed.
