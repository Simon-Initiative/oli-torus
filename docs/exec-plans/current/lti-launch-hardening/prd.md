# LTI Launch Hardening - Product Requirements Document

## 1. Overview
Torus must harden LTI 1.3 launches against browser privacy and cookie restrictions that intermittently break embedded LMS launches. This work item adds standards-aligned client-side OIDC and postMessage storage support where available, adds a fallback path when cookie-backed launch state is unavailable, and improves launch diagnostics so support and engineering can distinguish browser-session failures from LMS configuration errors.

## 2. Background & Problem Statement
Torus currently stores OIDC launch state in a cookie-backed Phoenix session during `/lti/login` and reads that state back during `/lti/launch`. Modern browser privacy controls, embedded iframe constraints, and multi-tab launch behavior can cause that state cookie to be blocked, dropped, or mismatched. When that happens, valid users experience intermittent LTI launch failures that are hard to reproduce and hard to diagnose. The current platform behavior is operationally weak in two ways: it relies on a cross-site cookie round trip for a critical authentication boundary, and it does not emit enough structured evidence to determine whether the failure was caused by browser privacy settings, user behavior, or a true LMS registration problem.

## 3. Goals & Non-Goals
### Goals
- Reduce intermittent LTI 1.3 launch failures caused by cross-site cookie and embedded-browser restrictions.
- Support standards-aligned client-side OIDC and postMessage storage flows when the LMS advertises the required capabilities.
- Provide a deterministic fallback path when cookie-backed launch state is unavailable or invalid.
- Emit actionable logs and telemetry so support can identify privacy-related launch failures quickly.
- Preserve existing LTI registration, deployment, authorization, and enrollment behavior for unaffected launches.

### Non-Goals
- Rework Torus registration and deployment administration flows.
- Introduce a generic top-level new-tab launch strategy for all LMS launches in this work item.
- Replace the underlying LTI library across the entire codebase.
- Redesign the learner or instructor post-launch experience outside of error and recovery messaging.

## 4. Users & Use Cases
- Students: launch a Torus course from an LMS iframe or embedded placement without intermittent cookie-related failures.
- Instructors: launch instructor-facing LTI entry points reliably and receive actionable guidance when their browser environment blocks the launch.
- Support and operations staff: determine from logs and telemetry whether a failed launch was caused by missing state, mismatched state, unsupported platform storage, or LMS configuration problems.
- LMS and institution administrators: configure supported LMS platforms without needing browser-specific workaround instructions for most users.

## 5. UX / UI Requirements
- When an LMS advertises the client-side OIDC / postMessage storage capability, the launch flow may insert an intermediate browser step, but that step must remain branded as Torus and must auto-continue without user input when possible.
- When the browser cannot complete a cookie-backed launch and the standards-based recovery path is unavailable or fails, the user must see a stable Torus error page that explains the launch could not be completed because browser privacy or cookie settings blocked the sign-in handshake.
- Recovery and error copy must distinguish likely browser/session issues from LMS registration/configuration issues in plain language suitable for instructors and students.
- Error surfaces must remain static and readable long enough for the user to capture the message or follow support instructions.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Reliability: the hardened launch flow shall preserve existing successful launch behavior for supported LMS registrations and shall not reduce success rates for unaffected browsers.
- Security: state, nonce, and launch-validation boundaries must remain CSRF-safe and replay-safe even when the browser-side storage path is used.
- Privacy: telemetry and logs shall not record raw id tokens, login hints, cookies, or personally identifying launch payloads beyond existing allowed operational metadata.
- Compatibility: the implementation shall support the current Phoenix cookie-backed session path as a fallback for platforms that do not advertise the newer browser-storage capability.
- Accessibility: any browser intermediary or recovery page introduced by the hardened flow shall remain keyboard accessible and screen-reader understandable.

## 9. Data, Interfaces & Dependencies
- The feature depends on Torus LTI 1.3 login and launch endpoints in `lib/oli_web/controllers/lti_controller.ex`.
- The feature depends on the LMS advertising standards-compatible launch capabilities for client-side OIDC and postMessage storage where available.
- The implementation may require a browser-side script or static page to exchange storage messages with the LMS and return launch parameters to Phoenix endpoints.
- New operational events should include launch outcome classification, flow path used, platform-storage availability, and state-validation outcome without including sensitive token payloads.

## 10. Repository & Platform Considerations
- Backend ownership belongs in `lib/oli/` and `lib/oli_web/`; launch validation and session handling must stay on the server-side boundary rather than moving core authorization decisions into frontend-only code.
- Torus uses Phoenix with cookie-backed sessions and LiveView-enabled layouts, so the design must work cleanly with existing endpoint session configuration and controller-rendered HTML.
- The work likely spans backend controllers/templates plus a focused browser-side integration surface, so verification should include targeted ExUnit controller tests and browser-flow tests only where necessary.
- Operational visibility should align with existing logging, telemetry, and AppSignal practices documented in `docs/OPERATIONS.md`.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Emit launch-path counters that distinguish server-session flow, client-side OIDC flow, fallback recovery flow, and terminal failure flow.
- Emit structured failure classification for missing state, mismatched state, missing browser storage support, recovery failure, and LMS configuration/registration failure.
- Success metric: reduced rate of LTI launch failures attributed to missing or mismatched launch state in production logs.
- Success metric: support can classify launch failures from logs without reproducing the user’s browser environment in the majority of cases.

## 13. Risks & Mitigations
- LMS capability variance: some platforms may not advertise or fully support the client-side OIDC / postMessage storage path. Mitigation: preserve the current server-session path and gate the browser-storage path on explicit capability checks.
- Security regression risk: changing state and nonce handling could weaken launch validation if implemented loosely. Mitigation: keep validation server-side, preserve replay protections, and add regression tests for valid and invalid state paths.
- Browser flow complexity: adding an intermediary browser step may create new failure modes. Mitigation: keep the flow minimal, auto-continue when possible, and instrument every branch.
- Support confusion during rollout: mixed old/new launch paths may make failure interpretation harder at first. Mitigation: standardize error classifications and log the flow path used for each launch.

## 14. Open Questions & Assumptions
### Open Questions
- Which LMS platforms used by Torus customers currently advertise and successfully complete the client-side OIDC / postMessage storage flow in embedded launches?
- Should Torus expose an administrator-visible compatibility indicator for registrations or deployments that cannot use the hardened browser-storage path?
- Do we want a future follow-up item for top-level or `_blank` launch fallback on platforms that cannot support embedded cookie-safe launches?

### Assumptions
- Browser privacy restrictions affecting third-party and embedded cookies are a material source of current intermittent LTI launch failures.
- Torus can introduce a narrow browser-side launch helper without changing the broader mixed Phoenix and LiveView architecture.
- Existing operational tooling can absorb new launch telemetry and structured logging without separate infrastructure work.

## 15. QA Plan
- Automated validation:
  - Controller tests for successful launches through the existing server-session path and the new client-side OIDC/postMessage storage path.
  - Negative tests for missing state, mismatched state, recovery path failure, and unsupported platform-storage capability.
  - Regression tests confirming stable user-facing error rendering and structured failure classification.
- Manual validation:
  - Launch from at least one LMS/browser combination that supports embedded storage-assisted launches.
  - Launch from a browser/privacy configuration that blocks third-party cookies and confirm the recovery path or actionable error message is shown.
  - Verify logs and telemetry distinguish the exact launch path and failure classification without leaking sensitive payload data.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
