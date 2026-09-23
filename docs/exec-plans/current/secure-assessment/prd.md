# Secure Assessment - Product Requirements Document

## 1. Overview

Enable instructors on supporting Torus instances to require secure delivery of graded assessments. Initially, students enter through the Moodle plugin's SEB-verified direct LTI resource launch. Only the resulting browser authentication session is confined to the assessment.

The primary product constraint is isolation: no secure session, including an abandoned or dangling one, may lock the same student out of ordinary launches or other ordinary sessions in the same or another section. Both basic and adaptive delivery and student review are in scope.

Source: `docs/exec-plans/current/secure-assessment/constrain.md`. Canonical detailed requirements and acceptance criteria: `docs/exec-plans/current/secure-assessment/requirements.yml`. This PRD captures the agreed product scope; implementation details in the source inform subsequent architecture and planning.

## 2. Background & Problem Statement

The branch's Moodle/SEB integration recognizes signed secure-launch evidence and supports direct assessment entry, but does not yet provide persistent assessment policy or consistent assessment-only authorization and UI.

Hiding navigation alone leaves direct URLs, APIs and connected views as alternate paths. Conversely, account-wide confinement would risk denying legitimate coursework after a browser closes without notifying Torus. Session-only confinement addresses the first problem without introducing the second. Attempt persistence and authentication lifetime remain separate.

## 3. Goals & Non-Goals

### Goals

- Give instructors a clear assessment-level secure-delivery setting on enabled instances.
- Make the assessment boundary consistent across basic/adaptive delivery, review and server interfaces.
- Preserve ordinary course access, saved work and established grading behavior.
- Establish a small provider-independent secure-admission boundary for later browser integrations.

### Non-Goals

- Account-wide restrictions, cross-device exam policing, mandatory browser-close detection, heartbeats or support-release workflows.
- Respondus implementation, a general plugin registry, continuous browser attestation, additional launch replay protection or diagnostic-bypass exclusion.
- A separate resource-binding registry, student exceptions, or changes to existing assessment timing and scoring policy.
- Moodle plugin redesign, institutional SEB configuration management or a new deep-linking picker.
- LTI activities and superactivities within assessments, including their provider launch/return/review adapters. This does not exclude Moodle LTI assessment admission or LMS grade passback.

## 4. Users & Use Cases

- Instructors: designate graded basic/adaptive assessments for secure delivery through Assessment Settings.
- Students: launch securely, work within the assessment, reconnect or resume saved work, submit and review.
- Students using ordinary sessions: continue coursework in any normally accessible section and review submitted attempts without waiting for a secure session to end.
- Instance operators: enable support through runtime configuration and deploy without exposing an unsupported setting.
- Future integration developers: add a verified entry adapter while reusing session scope, authorization and delivery behavior.

## 5. UX / UI Requirements

Use the existing Assessment Settings table patterns for the conditional **Secure Delivery** Yes/No column and its explanation. The secure learner shell retains assessment instructions, timer, save/connectivity status, question or adaptive-screen navigation, submission, permitted review, accessibility and exit; unrelated course navigation is absent.

Blocked assessment access explains that secure entry is required without implying that the account or course is locked. Unmet prerequisites and unsupported-instance errors provide a confined explanation and exit rather than a redirect loop. Ordinary course surfaces retain their normal behavior.

Basic and adaptive REVIEW mode must render submitted work read-only, including adaptive saved state and internal review navigation. Preserve keyboard operation, labels, focus visibility, skip links and established localization conventions. No Figma reference is supplied; use existing components and Tailwind patterns.

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)

Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Security: enforce authorization server-side before sensitive reads or writes; retain ownership, section and institution boundaries. Invalid admission fails only the affected session/request.
- Reliability: ordinary-session availability must not depend on secure-session cleanup, network presence, browser-close callbacks or account-wide state. Persisted attempts retain normal lifecycle semantics.
- Privacy: diagnostics exclude raw JWTs, cookies, authentication/socket credentials, student answers and unnecessary identity data.
- Accessibility: preserve existing accessible assessment interactions in both page types and review modes.
- Maintainability: keep entry-provider evidence separate from generic session scope and enforcement; favor existing authentication infrastructure over a new session lifecycle service.
- Performance: use bounded/set-based ownership resolution and current-session lookups; do not scan other learner sessions. Observe launch/save/reconnect latency through existing APM. No new numeric performance SLA is introduced, consistent with `harness.yml` defaults.

## 9. Data, Interfaces & Dependencies

The resource policy is `SectionResource.secure_delivery`, a boolean with false as the default and no student override. Instance capability is `SUPPORTS_SECURE_DELIVERY`, mapped to runtime application configuration.

The informal design proposes scope on existing authentication tokens using canonical section/resource IDs; exact API and persistence details belong in the FDD. Attempts remain the source of saved work, deadlines and completion state.

Initial dependencies include existing LTI registration/deployment/context resolution, Moodle's signed SEB assertion, Phoenix HTTP/LiveView/channel authentication, basic/adaptive activity dependencies, existing review policies and AGS passback. Admission must resolve the actual section resource rather than treating a claimed identifier as authorization. Future non-LTI adapters must produce equivalent verified identity/target input.

## 10. Repository & Platform Considerations

Follow `ARCHITECTURE.md`, `AGENTS.md` and `docs/STACK.md`: domain authorization belongs in Elixir contexts; transports/rendering use Phoenix/LiveView and existing React/adaptive applications. Preserve publication-pinned content and section overrides.

Relevant code boundaries include `lib/oli/delivery/settings/`, `lib/oli/delivery/sections/section_resource.ex`, `lib/oli/accounts/user_token.ex`, `lib/oli_web/user_auth.ex`, `lib/oli/lti/secure_launch.ex`, `lib/oli_web/lti_redirect.ex` and delivery controllers, LiveViews and channels.

Apply `docs/TESTING.md` and `docs/TOOLING.md` for targeted tests and formatting. Implementation review follows `docs/CODEREVIEW.md`, always covering security/performance plus relevant Elixir, UI/TypeScript and requirements lenses. Jira is the system of record per `docs/ISSUE_TRACKING.md`; no issue key was supplied and this analysis does not create or update an external issue.

## 11. Feature Flagging, Rollout & Migration

The explicitly requested runtime capability is in scope despite the repository's default of excluding additional feature flags. Use `SUPPORTS_SECURE_DELIVERY=false` by default, enable supporting instances through deployment configuration, and keep all nodes consistent. No additional scoped feature flag is proposed.

Deploy schema and enforcement before enabling instructor controls. The runtime setting is read at startup and requires restart, not recompilation. Unsupported instances omit the column and reject enabling through other update paths.

Preserve pre-existing protected-resource policy when support is disabled; deny new secure admissions for that resource without affecting ordinary coursework or permitted review. Existing scoped tokens do not become unrestricted. Replace the spike's deployment-wide SEB gate with resource-driven admission so ordinary launches remain independent.

Generate Ecto migrations with explicit up/down functions and verify rollback. A rollback that removes token scope must first invalidate only the affected secure credentials; it must not turn them into unrestricted credentials or revoke ordinary sessions.

## 12. Telemetry & Success Metrics

Per `harness.yml` and `docs/OPERATIONS.md`, use existing telemetry/AppSignal for bounded admission outcomes, denial reasons and explicit secure-session exits. Distinguish ordinary, secure and review operations without logging credentials, answers or high-cardinality learner identifiers. Do not infer browser closure or exam abandonment from missing events.

Release success means all isolation cases and the basic/adaptive delivery/review matrix pass, protected entry is denied without valid admission, and secured submissions retain correct grade passback. Observe launch/authorization errors and latency after enablement; any confirmed cross-session restriction attributable to this feature is a release-blocking regression. Detailed observability acceptance is canonical in requirements.yml.

## 13. Risks & Mitigations

- Dangling secure credentials: authorization depends only on the current token; test ordinary access with orphaned secure tokens retained and no cleanup.
- URL/API/socket bypass or batch ownership mismatch: resolve canonical target ownership and cover all entry/read/write surfaces before release.
- Adaptive review unintentionally writes state: test real REVIEW mode and reject mutation through review dependencies.
- Deployment-wide spike settings reject regular launches: explicitly retire that gating behavior for ordinary targets and test the old broad configuration.
- Concurrent ordinary launches alter shared LTI metadata: verify grade routing with interleaved launches; resolve grade binding rather than denying ordinary access.
- Unsupported-instance or rollback transitions drop protection: preserve stored policy, avoid unscoping credentials and verify migrations.
- Native activities/media need scoped services: exercise required dependencies without blanket endpoint exemptions. Embedded LTI activities and superactivities are excluded by the confirmed scope.
- Misunderstood security boundary: clearly state that other ordinary devices remain usable and Moodle supplies launch-time SEB evidence.

## 14. Open Questions & Assumptions

### Open Questions

- No blocking product questions remain from the supplied description. The implementation/pilot owner must record the representative Moodle/SEB environments and assessment dependency examples used for end-to-end verification.
- A Jira work-item key has not been supplied; link it when available without delaying local PRD preparation.

### Assumptions

- The latest session-only decisions supersede earlier account-wide confinement and finish-before-exit proposals.
- The no-lockout guarantee concerns this feature's secure-session state; normal enrollment/authentication failures and unrelated outages remain possible.
- Existing Moodle verification is the initial evidence authority. Browser-close revocation and continuous attestation are not promised.
- Ordinary submitted-attempt review is allowed even while another secure session is live. Protected delivery remains blocked without admission.
- Respondus remains a future adapter, not a current implementation or verification dependency.
- Existing attempt concurrency and timed auto-submit rules remain authoritative; secure relaunch does not reset them.

## 15. QA Plan

- Automated validation: ExUnit for configuration, settings, admission, token scope and ownership; controller/LiveView/channel tests for direct access, events, reconnect and isolated logout; Jest where adaptive/client behavior changes.
- Workflow coverage: use `Oli.Scenarios` for real settings/publish/section/attempt flows without fixture-based domain setup. Validate YAML and run targeted scenario runners.
- Isolation coverage: same learner, independent secure/ordinary cookie jars, same/different sections and the same deployment; keep secure credentials live, submitted, abandoned, expired, revoked and dangling while exercising existing and new ordinary access.
- Manual validation: basic and adaptive SEB entry/save/reconnect/submit/review, ordinary review, logout before completion, browser closure without logout, second-computer ordinary launch and correct Moodle grade placement.
- Release checks: migration up/down, unsupported-instance UI/update paths, scope-preserving disablement, route/dependency classification, accessible secure UI and telemetry privacy.
- Capture intentional test logs according to repository policy. Run relevant backend/frontend checks before implementation commits; no application implementation is claimed by this PRD.

## 16. Definition of Done

- [x] PRD sections complete with scope, assumptions, risks and verification expectations.
- [x] requirements.yml captured with canonical proposed requirements and acceptance criteria.
- [x] Requirements structure and PRD validation pass.
- [ ] Implementation satisfies all canonical acceptance criteria and records proof during development.
- [ ] Basic/adaptive delivery/review and no-lockout evidence are retained before rollout.

## Decision Log

### 2026-09-23 — Native assessment activity scope

- Change: LTI activities and superactivities embedded in assessments are excluded. Earlier provider-adapter inventory entries are historical, not remaining implementation or release requirements.
- Reason: Explicit user scope clarification; retain both basic/adaptive pages, read-only review guards and existing feedback filtering.
- Evidence: `docs/exec-plans/current/secure-assessment/phase-5-execution.md` and AC-024 in `docs/exec-plans/current/secure-assessment/requirements.yml`.
- Impact: Phase 5 covers native assessment rendering/state/models/media/uploads. Moodle LTI admission and LMS grade passback are unchanged; excluded activity routes gain no secure-session exemption.
