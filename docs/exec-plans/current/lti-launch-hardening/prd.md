# LTI Launch Hardening - Product Requirements Document

## 1. Overview

Redesign the Torus LTI 1.3 launch lifecycle so embedded LMS launches use a database-backed launch authority, can optionally use storage-assisted launch state transport when the LMS advertises `lti_storage_target`, and degrade cleanly when embedded browser privacy settings still block Torus session continuity after a successful launch. The redesign must also make launch routing deterministic from the current validated launch, separate launch and onboarding concerns, and improve telemetry plus stable user-facing error handling.

## 2. Background & Problem Statement

Torus currently relies too heavily on browser-managed session continuity between `/lti/login`, registration-related handling, `/lti/launch`, and the first protected delivery request after launch. In embedded LMS contexts, browser privacy controls can block or degrade third-party and iframe cookie behavior, which causes intermittent launch failures, sign-in redirects instead of authenticated landing, onboarding context loss, and ambiguous recovery behavior. The present design also allows immediate post-launch routing to depend on user-global historical launch state rather than only on the current validated launch, which makes routing less precise and harder to diagnose.

Implementation work on this branch clarified an important architectural limit: even when the LTI state handshake succeeds without depending on Phoenix session continuity, Torus delivery still depends deeply on its own authenticated web session model. That means `lti_storage_target` can help the OIDC launch handshake, but it does not by itself make embedded Torus delivery fully cookieless. The system therefore needs a canonical per-launch state boundary owned by the server, support for standards-aligned storage-assisted embedded launches when advertised by the LMS, a clean post-launch fallback when the first embedded Torus session does not survive, and stable terminal classification for launch failures. The canonical launch state should be implemented as a database-backed `launch_attempts` store with explicit `expires_at` handling and cleanup rather than a node-local cache or browser-session authority. It also needs better operational visibility so production launch failures can be attributed to concrete lifecycle stages rather than inferred from scattered symptoms.

## 3. Goals & Non-Goals

### Goals

- Support standards-aligned cookieless or storage-assisted embedded LTI launch behavior when the LMS advertises the required capability.
- Fall back to the existing cookie or session-based launch behavior when the LMS does not advertise `lti_storage_target`.
- Detect when a launch succeeded but embedded Torus session continuity is still unavailable on the first post-launch landing request.
- Provide a controlled post-launch recovery experience that either offers “Open Torus in a new tab” or renders a stable embedded-browser privacy error, based on a feature flag.
- Introduce a single authoritative server-owned per-launch state boundary that is created during `/lti/login` and resolved during `/lti/launch`.
- Implement the canonical launch-attempt boundary as a database row with `expires_at` and cleanup so it works across multi-node deployments without introducing a new infrastructure service.
- Ensure immediate post-launch routing uses only the current validated launch context.
- Remove or deprecate `get_latest_user_lti_params/1` and eliminate its use in the immediate launch redirect path.
- Technically decouple registration onboarding from launch-state transport assumptions while preserving required onboarding outcomes.
- Use explicit URL parameters such as `issuer`, `client_id`, and `deployment_id` to hand off into the admin registration-request form when registration or deployment cannot be found, rather than relying on Phoenix session state.
- Narrow helper and recovery flows so they do not become hidden alternate state-transport layers.
- Classify launch lifecycle failures into stable, explicit categories with durable user-facing outcomes.
- Improve logging and telemetry so support and engineering can diagnose launch path selection, validation outcomes, state failures, and handler failures without exposing sensitive payloads.
- Explicitly log and emit telemetry for the launch-state transport method used on every successful and failed launch, using stable values `lti_storage_target` and `session_storage`.
- Fix embedded launch terminal pages so they remain stable and do not escalate into unrelated LiveView reconnects, 404s, or frontend JavaScript crashes.
- Make the LTI registration form usable in iframe contexts without depending on Phoenix CSRF session continuity for the registration endpoints.
- Preserve `lti_1p3` as the lower-level protocol and validation layer, with any necessary upstream changes released as `lti_1p3` `0.12.0` before the final Torus PR ships.

### Non-Goals

- Redesign broad LMS administration UX beyond the launch and onboarding changes required by this work.
- Replace `lti_1p3` with a Torus-specific protocol implementation.
- Redesign unrelated learner or instructor post-launch product surfaces.
- Build a broad browser compatibility support matrix UI beyond the diagnostics and recovery behavior needed for launch reliability.
- Solve every historical LMS integration issue that is not part of launch-state transport, launch routing, onboarding decoupling, or lifecycle observability.

## 4. Users & Use Cases

- Students: launch Torus from an embedded LMS placement and land in the correct course destination even when cross-site cookie continuity is unavailable.
- Instructors: launch instructor-facing Torus placements reliably and receive clear, stable failure guidance when browser or LMS conditions prevent completion.
- Institution and LMS administrators: distinguish invalid registration or deployment issues from browser-state or storage limitations without ambiguous sign-in or 404 outcomes.
- Support and operations staff: inspect telemetry and logs to determine which launch path ran, where the lifecycle failed, and whether the failure was caused by state transport, validation, onboarding, or landing behavior.
- Engineers maintaining LTI support: evolve launch behavior while preserving a clean boundary with `lti_1p3` and a deployment-safe multi-node architecture.

## 5. UX / UI Requirements

- Embedded launches that use storage-assisted behavior may include a narrow intermediate Torus-managed step, but the step must auto-continue when possible and must not require extra user choices for the normal happy path.
- Launch failures must render stable Torus-owned error states that remain visible and readable instead of redirecting to unrelated sign-in, 404, or generic failure pages.
- User-facing launch error copy must be sanitized and must explain the failure category and next step in plain language without exposing raw launch claims, tokens, cookies, session values, stack traces, or registration secrets.
- Error states must distinguish likely browser or storage problems from invalid LMS registration or deployment problems.
- Onboarding-related failures must be presented as onboarding outcomes, not as generic launch-validation failures.
- Recovery guidance for blocked browser storage must remain generic and actionable, including instructing the user to allow cookies when appropriate or contact their LMS administrator if the tool must be launched in a top-level tab.
- When a launch succeeds but the first embedded Torus session is unavailable, the landing experience must either:
  - show a clear “Continue in a new tab” call to action, or
  - show a stable error explaining that Torus cannot continue inside the iframe and must be opened in a new tab,
  depending on feature-flag state.
- The LTI error page must remain a static terminal surface and must not mount nested LiveView behavior that can trigger follow-up requests to invalid routes.
- The registration form must render and submit inside an LMS iframe without crashing on missing optional prepopulation data.

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)

Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Reliability: the per-launch state mechanism must support multi-node and replica deployments through a shared database-backed launch-attempt store and must classify missing, mismatched, expired, or consumed launch attempts deterministically.
- Security: the redesigned lifecycle must preserve CSRF, nonce, replay-protection, registration-validation, and deployment-validation guarantees.
- Privacy: logs and telemetry must exclude raw id tokens, cookies, session contents, login hints, registration secrets, and other sensitive launch payloads.
- Maintainability: launch-state creation, validation, consumption, classification, and immediate routing must have a documented single authority rather than multiple overlapping state sources.
- Accessibility: any intermediate launch page, recovery page, or error state introduced by this work must remain keyboard accessible and screen-reader understandable.
- Performance: the new per-launch state mechanism and telemetry must not materially regress launch latency for successful launches.
- Compatibility: the first post-launch fallback surface must preserve current-system redirect behavior so “continue” actions resolve against the latest section state rather than stale launch-time snapshots.

## 9. Data, Interfaces & Dependencies

- The work affects `/lti/login` and `/lti/launch` plus any helper endpoints or templates used to continue embedded launches safely.
- The work also affects a dedicated post-launch landing endpoint used to determine whether embedded Torus session continuity survived and to apply fallback behavior when it did not.
- The canonical launch-attempt record must be persisted in the application database and must store enough non-sensitive lifecycle metadata to validate, classify, consume, and diagnose the launch across clustered app nodes.
- The launch-attempt record must include explicit expiry via `expires_at` and must be removed by a cleanup job after the active or unconsumed window passes.
- Immediate launch routing must consume the current validated launch claims and must not depend on `get_latest_user_lti_params/1` or equivalent user-global latest-launch lookups.
- The post-launch landing path must also resolve destinations from current system state using the launch attempt as authority, not from a stale destination captured when the fallback page was first rendered.
- The registration-request form for invalid registration or invalid deployment must load its initial rendered values from explicit URL parameters such as `issuer`, `client_id`, and `deployment_id` rather than from Phoenix session state.
- Invalid registration and invalid deployment handoff should be treated as a single-use render path rather than a long-lived refreshable state; after the initial render, form resubmission handling should rely on submitted form values instead of rereading launch handoff state.
- The implementation continues to depend on `lti_1p3` for lower-level validation and protocol enforcement.
- If Torus needs temporary `.vendor/lti_1p3` changes during implementation, those changes must be merged upstream, released as `0.12.0`, and replaced with the Hex dependency before the final Torus PR.
- Telemetry and logging should include launch path, launch-state transport method, lifecycle stage, failure classification, recovery-path usage, and keyset lookup diagnostics using non-sensitive metadata only.
- The work depends on LMS capability signaling for storage-assisted launches when standards-aligned cookieless behavior is available, and must preserve the existing cookie or session-based path when `lti_storage_target` is not advertised.
- Storage-assisted launch behavior must be independently controllable behind a feature flag so rollout can force all launches back to `session_storage` even when an LMS advertises `lti_storage_target`.
- The new-tab continuation fallback must be independently controllable behind a separate feature flag so rollout can choose between an actionable new-tab recovery surface and a terminal embedded-browser privacy error.

## 10. Repository & Platform Considerations

- Torus is a Phoenix application with focused React surfaces, so core launch lifecycle decisions must remain on the server boundary in `lib/oli/` and `lib/oli_web/`.
- The implementation should respect existing LTI boundaries and keep `lti_1p3` as the lower-level validation layer instead of spreading protocol rules through controller or frontend-only code.
- Multi-node deployment support means the canonical per-launch state cannot depend on single-node memory, ETS, or browser cookie continuity alone; it must rely on the shared database.
- Verification should emphasize targeted ExUnit coverage for launch classification, state lifecycle, routing behavior, onboarding decoupling, and stable error rendering, with frontend coverage only where a browser-side storage helper or intermediate page is introduced.
- Operational behavior should align with existing AppSignal, logging, and telemetry practices documented for the repository.
- Jira is the system of record for feature execution tracking in this repository and should be used for implementation follow-through once planning is approved.

## 11. Feature Flagging, Rollout & Migration

- `lti-storage-target`
  - Purpose: controls whether Torus is allowed to honor LMS-advertised `lti_storage_target` and run the storage-assisted login helper path.
  - Default: enabled.
  - Disabled behavior: Torus always uses `session_storage` for launch-state transport even if the LMS advertises `lti_storage_target`.
- `lti-new-tab-fallback`
  - Purpose: controls whether a successful launch with failed embedded Torus session continuity shows a “Continue in a new tab” recovery page.
  - Default: disabled.
  - Disabled behavior: Torus renders a stable embedded-browser privacy error instead of the new-tab recovery page.
- Rollout should treat these flags independently so teams can:
  - disable storage-assisted launch transport without removing the broader launch-attempt and observability improvements, or
  - enable or disable post-launch new-tab recovery messaging independently of launch transport selection.

## 12. Telemetry & Success Metrics

- Emit structured telemetry and logs for launch-attempt creation, launch path selection, launch validation outcome, launch-attempt consumption, recovery-path entry, and terminal failure classification.
- Emit structured telemetry and logs for the launch-state transport method used on every successful and failed launch, with stable values `lti_storage_target` and `session_storage`.
- Emit structured telemetry and logs for launch-attempt expiry and cleanup outcomes so operators can detect buildup or cleanup failures for active or unconsumed attempts.
- Emit structured diagnostics for keyset lookup and `kid` resolution failures, including lookup source, requested `kid`, cached key identifiers, cache freshness context when available, and terminal classification without leaking token payloads.
- Emit separate classifications for launch failure, onboarding failure, and post-auth landing failure so production issues can be attributed to the correct lifecycle stage.
- Emit recovery-path telemetry for post-launch landing decisions, including whether the landing request continued normally, showed the new-tab fallback, or rendered the embedded-session-unavailable error.
- Success signal: embedded launches that advertise storage-assisted capability succeed without Phoenix session continuity being the only launch-state transport.
- Success signal: immediate redirect behavior no longer consults `get_latest_user_lti_params/1`.
- Success signal: launch failures consistently render stable classified error pages rather than sign-in redirects or unrelated 404 outcomes.
- Success signal: when embedded Torus session continuity fails after a valid launch, users receive a deterministic fallback or error surface instead of a redirect to `/users/log_in`.
- Success signal: support can identify the launch path and stable failure category from logs and telemetry in the majority of production incidents.
- Success signal: support and QA can determine from logs and telemetry whether a launch used `lti_storage_target` or `session_storage` for both success and failure cases.

## 13. Risks & Mitigations

- LMS capability variance may make storage-assisted behavior inconsistent across platforms: gate that path on explicit capability signals and preserve a safe legacy path where still valid.
- Even with storage-assisted launch state, embedded Torus delivery can still fail if the first authenticated Torus session cookie does not survive in the iframe: route successful launches through a dedicated landing boundary and provide a controlled fallback or terminal error based on feature flags.
- Introducing a new per-launch state boundary could create duplicate authorities if not enforced consistently: define one canonical database-backed launch-attempt abstraction and remove immediate-routing dependence on legacy latest-launch lookups and Phoenix session handoff state.
- Registration-request handoff may uncover hidden dependencies on session or CSRF assumptions: load the initial registration form from explicit URL parameters on a normal GET route, treat the handoff as single-use, and test invalid-submit re-rendering from posted form values separately from launch validation.
- Better user-facing errors could accidentally expose sensitive internals: define a sanitized error taxonomy and keep detailed diagnostics only in protected logs and telemetry.
- Shared layouts can accidentally mount interactive behavior on terminal launch pages: keep LTI error surfaces static and test against follow-up reconnect or 404 regressions.
- Temporary `lti_1p3` vendoring could drift from the final dependency state: treat upstream merge and `0.12.0` release as a required completion gate for the final Torus PR.
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
