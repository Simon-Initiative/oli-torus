# LTI Launch Hardening - Product Requirements Document

## 1. Overview

Torus must harden LTI 1.3 launches against browser privacy and cookie restrictions that intermittently break embedded LMS launches. This work item adds standards-aligned client-side OIDC and postMessage storage support where available, adds a fallback path when cookie-backed launch state is unavailable, and improves launch diagnostics so support and engineering can distinguish browser-session failures from LMS configuration errors.

## 2. Background & Problem Statement

Torus currently stores OIDC launch state in a cookie-backed Phoenix session during `/lti/login` and reads that state back during `/lti/launch`. Modern browser privacy controls, embedded iframe constraints, and multi-tab launch behavior can cause that state cookie to be blocked, dropped, or mismatched. When that happens, valid users experience intermittent LTI launch failures that are hard to reproduce and hard to diagnose. The current platform behavior is operationally weak in two ways: it relies on a cross-site cookie round trip for a critical authentication boundary, and it does not emit enough structured evidence to determine whether the failure was caused by browser privacy settings, user behavior, or a true LMS registration problem.

Torus also persists broad LTI launch payloads in ways that are not tightly aligned to current launch decisions. In particular, post-launch routing has historically depended on recalling a user's latest stored LTI params rather than the current validated launch context. This creates stale-context risk and makes launch-state handling less precise than it should be.

## 3. Goals & Non-Goals

### Goals

- Reduce intermittent LTI 1.3 launch failures caused by cross-site cookie and embedded-browser restrictions.
- Support standards-aligned client-side OIDC and postMessage storage flows when the LMS advertises the required capabilities.
- Own the client-side OIDC login and request-construction path in Torus application code while continuing to leverage lower-level `lti_1p3` primitives for launch validation, registration lookup, and related protocol enforcement.
- Provide a deterministic fallback path when cookie-backed launch state is unavailable or invalid, including clear recovery guidance for LMS launches that must be opened as a top-level tab.
- Emit actionable logs and telemetry so support can identify privacy-related launch failures quickly.
- Ensure LTI launch failures render as clear, stable error pages that explain the failure category without exposing sensitive launch details or redirecting into unrelated 404 pages.
- Eliminate routing decisions that depend on recalling a user's latest persisted launch blob when the current validated launch context is available.
- Preserve existing LTI registration, deployment, authorization, and enrollment behavior for unaffected launches.

### Non-Goals

- Rework Torus registration and deployment administration flows.
- Implement a tool-controlled relaunch mechanism that overrides LMS launch placement.
- Replace the underlying LTI library across the entire codebase.
- Fork or broadly rewrite `lti_1p3` when the required hardened flow can be implemented by taking ownership of the login/request-construction layer in Torus.
- Redesign the learner or instructor post-launch experience outside of error and recovery messaging.

## 4. Users & Use Cases

- Students: launch a Torus course from an LMS iframe or embedded placement without intermittent cookie-related failures.
- Instructors: launch instructor-facing LTI entry points reliably and receive actionable guidance when their browser environment blocks the launch.
- Support and operations staff: determine from logs and telemetry whether a failed launch was caused by missing state, mismatched state, unsupported platform storage, or LMS configuration problems.
- LMS and institution administrators: configure supported LMS platforms without needing browser-specific workaround instructions for most users.

## 5. UX / UI Requirements

- When an LMS advertises the client-side OIDC / postMessage storage capability, the launch flow may insert an intermediate browser step, but that step must remain branded as Torus and must auto-continue without user input when possible.
- When the browser cannot complete a cookie-backed launch and the standards-based recovery path is unavailable or fails, the user must see a stable Torus recovery page that explains the launch could not be completed because browser privacy or cookie settings blocked the sign-in handshake and that the user should either allow cookies for the launch flow or ask their LMS administrator to configure Torus to open in a new tab.
- Recovery and error copy must distinguish likely browser/session issues from LMS registration/configuration issues in plain language suitable for instructors and students.
- Error surfaces must remain static and readable long enough for the user to capture the message or follow support instructions.
- When LTI launch validation or launch handling fails, Torus must render a stable launch-error page that preserves the visible error state instead of redirecting to a generic 404 or otherwise obscuring the reason for failure.
- User-facing LTI error copy must be sanitized so it communicates the failure category and next step without exposing raw tokens, session values, stack traces, registration secrets, or other sensitive internals.
- The recovery page must make clear that Torus cannot change the launch placement itself and that the required next step, when cookies remain unavailable and storage-safe fallback is not supported, is an LMS-side open-in-new-tab or equivalent top-level launch configuration.
- Recovery copy should remain generic and non-LMS-specific rather than naming platform-specific settings or navigation paths.

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)

Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Reliability: the hardened launch flow shall preserve existing successful launch behavior for supported LMS registrations and shall not reduce success rates for unaffected browsers.
- Security: state, nonce, and launch-validation boundaries must remain CSRF-safe and replay-safe even when the browser-side storage path is used.
- Privacy: telemetry and logs shall not record raw id tokens, login hints, cookies, or personally identifying launch payloads beyond existing allowed operational metadata.
- Privacy: user-facing launch errors shall not reveal raw id tokens, cookies, session values, stack traces, registration secrets, or personally identifying launch payloads beyond existing allowed operational metadata.
- Compatibility: the implementation shall support the current Phoenix cookie-backed session path as a fallback for platforms that do not advertise the newer browser-storage capability.
- Accessibility: any browser intermediary or recovery page introduced by the hardened flow shall remain keyboard accessible and screen-reader understandable.

## 9. Data, Interfaces & Dependencies

- The feature depends on Torus LTI 1.3 login and launch endpoints in `lib/oli_web/controllers/lti_controller.ex`.
- The feature depends on the LMS advertising standards-compatible launch capabilities for client-side OIDC and postMessage storage where available.
- The implementation may require a browser-side script or static page to exchange storage messages with the LMS and return launch parameters to Phoenix endpoints.
- For the client-side OIDC path, Torus should construct the login request in application code and may bypass higher-level `lti_1p3` login helpers while still relying on lower-level `lti_1p3` validation and registration facilities.
- New operational events should include launch outcome classification, flow path used, platform-storage availability, embedded-versus-top-level context signals where detectable, recovery-page presentation, and state-validation outcome without including sensitive token payloads.
- The implementation depends on preserving static LTI error rendering through the existing Phoenix controller/template boundary rather than allowing downstream UI behavior to replace launch errors with unrelated 404 states.
- The implementation should normalize persisted launch context around the claims Torus actually needs for durable behavior, such as issuer, client identifier, deployment, context, resource link, roles, expiration, and platform service endpoints, rather than relying on a raw launch blob as the primary durable artifact.

## 10. Repository & Platform Considerations

- Backend ownership belongs in `lib/oli/` and `lib/oli_web/`; launch validation and session handling must stay on the server-side boundary rather than moving core authorization decisions into frontend-only code.
- Torus uses Phoenix with cookie-backed sessions and LiveView-enabled layouts, so the design must work cleanly with existing endpoint session configuration and controller-rendered HTML.
- The work likely spans backend controllers/templates plus a focused browser-side integration surface, so verification should include targeted ExUnit controller tests and browser-flow tests only where necessary.
- The architecture should preserve `lti_1p3` as the lower-level protocol validation layer where practical, while moving the client-side OIDC login orchestration boundary into Torus-owned code.
- Operational visibility should align with existing logging, telemetry, and AppSignal practices documented in `docs/OPERATIONS.md`.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item

## 12. Telemetry & Success Metrics

- Emit launch-path counters that distinguish server-session flow, client-side OIDC flow, fallback recovery flow, and terminal failure flow.
- Emit structured failure classification for missing state, mismatched state, missing browser storage support, embedded cookie/storage restrictions, recovery-page presentation, and LMS configuration/registration failure.
- Emit structured failure classification for launch errors that were rendered to the user versus failures that transitioned into recovery handling, so support can distinguish visible LTI validation failures from masked navigation failures.
- Success metric: reduced dependence of routing and section resolution on recalled latest-user launch records in production code paths.
- Success metric: reduced rate of LTI launch failures attributed to missing or mismatched launch state in production logs.
- Success metric: support can classify launch failures from logs without reproducing the user’s browser environment in the majority of cases.

## 13. Risks & Mitigations

- LMS capability variance: some platforms may not advertise or fully support the client-side OIDC / postMessage storage path. Mitigation: preserve the current server-session path and gate the browser-storage path on explicit capability checks.
- Security regression risk: changing state and nonce handling could weaken launch validation if implemented loosely. Mitigation: keep validation server-side, preserve replay protections, and add regression tests for valid and invalid state paths.
- Browser flow complexity: adding an intermediary browser step may create new failure modes. Mitigation: keep the flow minimal, auto-continue when possible, and instrument every branch.
- Support confusion during rollout: mixed old/new launch paths may make failure interpretation harder at first. Mitigation: standardize error classifications and log the flow path used for each launch.
- Error leakage risk: clearer launch errors could accidentally expose sensitive launch internals if copied directly from lower-level exceptions. Mitigation: define a sanitized user-facing error taxonomy and keep detailed diagnostics only in protected logs and telemetry.
- Dependency-boundary risk: Torus could end up with an awkward split between app-owned login orchestration and library-owned validation if the boundary is not explicit. Mitigation: formally define Torus as the owner of client-side OIDC login/request construction and `lti_1p3` as the lower-level validation and registration layer.
- LMS control boundary risk: users may assume Torus can relaunch itself in a top-level tab even when the LMS controls placement. Mitigation: make the recovery copy explicit that the required change is LMS-side configuration or a user/admin relaunch from an LMS top-level-tab option, while keeping the instructions generic rather than LMS-specific.

## 14. Open Questions & Assumptions

### Open Questions

- Which LMS platforms used by Torus customers currently advertise and successfully complete the
  client-side OIDC / postMessage storage flow in embedded launches?
  - Canvas
  - Moodle
  - Brightspace D2L
- Should Torus expose an administrator-visible compatibility indicator for registrations or
  deployments that cannot use the hardened browser-storage path?
  Yes
- The recovery page should use generic instructions that tell users to allow cookies when possible or ask their LMS administrator to configure Torus to open in a new tab when browser storage-safe fallback methods are unavailable.
- Which existing Torus features, admin views, or support workflows still depend on the full persisted `params` launch blob?

### Assumptions

- Browser privacy restrictions affecting third-party and embedded cookies are a material source of current intermittent LTI launch failures.
- Torus can introduce a narrow browser-side launch helper without changing the broader mixed Phoenix and LiveView architecture.
- Existing operational tooling can absorb new launch telemetry and structured logging without separate infrastructure work.
- The existing static LTI error page pattern can be reused as the baseline for visible, non-obscured launch errors.
- Torus can satisfy current product needs with a narrower persisted launch-context model.
- Torus can implement the hardened client-side OIDC flow without modifying `lti_1p3` by taking ownership of login/request construction while continuing to use the library's lower-level validation primitives.

## 15. QA Plan

- Automated validation:
  - Controller tests for successful launches through the existing server-session path and the new client-side OIDC/postMessage storage path.
  - Coverage confirming the client-side OIDC path uses Torus-owned login/request construction while still succeeding through the existing lower-level `lti_1p3` validation boundary.
  - Negative tests for missing state, mismatched state, recovery path failure, unsupported platform-storage capability, and embedded cookie-loss cases that must render the top-level-launch recovery page.
  - Regression tests confirming stable user-facing error rendering, sanitized LTI error copy, and no redirect from launch errors into unrelated 404 pages.
  - Regression tests confirming immediate post-launch routing uses the current validated launch context rather than a recalled latest-user launch blob.
- Manual validation:
  - Launch from at least one LMS/browser combination that supports embedded storage-assisted launches.
  - Launch from a browser/privacy configuration that blocks third-party cookies and confirm the recovery page explains the browser-storage failure and generically instructs the user to allow cookies or ask their LMS administrator to configure Torus to open in a new tab.
  - Trigger representative LTI validation and launch-handling failures and confirm the user sees a stable Torus error page that explains the failure category without exposing sensitive details or being replaced by a 404.
  - Verify a user with multiple LTI contexts or recent launches is routed according to the current validated launch rather than whichever launch record was updated most recently.
  - Verify logs and telemetry distinguish the exact launch path and failure classification without leaking sensitive payload data.

## 16. Definition of Done

- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
