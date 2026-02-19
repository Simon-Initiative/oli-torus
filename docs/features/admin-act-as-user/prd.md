# Admin Act-as-User (Masquerade) — PRD

## 1. Overview
Feature Name: Admin Act-as-User (Masquerade)

Summary: Add a system-admin-only masquerade capability that allows an admin to enter the platform as a selected user from the admin user detail page, while preserving an explicit system record that the session is a masquerade. The acting session must visually stand out with a bright magenta full-viewport border and persistent bottom bar, and support an explicit stop action that restores the admin's normal session.

Links: None

## 2. Background & Problem Statement
- Current behavior / limitations:
  - System administrators can inspect user records but cannot verify user-facing behavior end-to-end using the exact permissions/context of a target user.
  - Troubleshooting issues across delivery experiences requires manual role simulation or direct data inspection, which is slower and less reliable.
  - There is no explicit audit trail for impersonation start/end events.
- Affected users/roles:
  - System admins (primary users of this capability).
  - Learners/instructors indirectly benefit from faster support and diagnostics.
- Why now:
  - Support and QA workflows need high-confidence reproduction of user issues while maintaining security controls and auditability.

## 3. Goals & Non-Goals
- Goals:
  - Allow a system admin to initiate "Act as user" from `lib/oli_web/live/users/user_detail_view.ex`.
  - Require a confirmation step before impersonation starts.
  - Ensure runtime behavior uses the selected user as the effective authenticated user across views.
  - Show persistent, high-visibility masquerade chrome (magenta border + bottom bar with target identity + stop action).
  - Audit exactly when impersonation starts and stops, and which admin initiated/stopped it.
  - Gate the feature behind a system-level feature flag.
  - Structure the design so "Act as author" can be added later with minimal architecture changes.
- Non-Goals:
  - Acting as author accounts in this phase.
  - Bulk impersonation operations.
  - Long-term impersonation history UI beyond existing audit log browsing.
  - Cross-browser/session synchronization beyond the active browser session.

## 4. Users & Use Cases
- Primary Users / Roles:
  - System Administrator (`current_author` with `:system_admin`) in admin dashboard.
- Use Cases:
  - Admin opens a specific user in `/admin/users/:user_id`, selects "Act as user", confirms identity details, and enters a masquerade session.
  - While acting, admin navigates delivery and user-facing pages and sees behavior identical to that user.
  - Admin ends acting via "Stop acting as user" from the global bottom bar and returns to their normal admin session.
  - Security/compliance reviewer verifies start/end audit events in `/admin/audit_log`.

## 5. UX / UI Requirements
- Key Screens/States:
  - User detail actions include new `Act as user` action (enabled only for system admins when feature flag is on).
  - Confirmation screen titled `Act as <user name>` displaying at minimum: email and independent learner status, with `Proceed` and `Cancel`.
  - Active masquerade state includes:
    - Bright magenta border around the entire viewport.
    - Persistent bottom bar with left text `Acting as <User Name>` and right action `Stop acting as user`.
- Navigation & Entry Points:
  - Entry from `lib/oli_web/live/users/user_detail_view.ex` (Actions section).
  - Cancel returns to the originating user detail page.
  - Stop action is globally available while acting.
- Accessibility:
  - Confirmation and stop controls must be keyboard accessible and screen-reader labeled.
  - Magenta border/bar must preserve WCAG 2.1 AA text contrast for all text displayed on/over the chrome.
  - Focus should move to confirmation heading on load and to a success flash after state transitions.
- Internationalization:
  - All new user-facing/admin-facing strings use gettext.
- Screenshots/Mocks:
  - None

## 6. Functional Requirements
| ID | Description | Priority | Owner |
|---|---|---|---|
| FR-001 | Add an `Act as user` action in admin user detail (`/admin/users/:user_id`) for system admins when the system feature flag is enabled. | P0 | Backend |
| FR-002 | Clicking `Act as user` must navigate to a confirmation screen with target identity details and `Proceed`/`Cancel` actions. | P0 | Backend |
| FR-003 | Proceeding creates a masquerade session that sets the selected user as effective authenticated user context for request handling and LiveView mounts. | P0 | Backend |
| FR-004 | Masquerade session must preserve admin identity metadata separately so the system knows session is impersonated. | P0 | Backend |
| FR-005 | While masquerading, render global high-visibility chrome: bright magenta full-viewport border and bottom status bar with acting identity and stop button. | P0 | Backend |
| FR-006 | `Stop acting as user` must terminate masquerade and restore pre-masquerade session state deterministically. | P0 | Backend |
| FR-007 | Audit events must be written when masquerade starts and when it ends, including acting admin account and target user identity IDs. | P0 | Backend |
| FR-008 | Enforce authorization: only system admins can start/stop masquerade; non-admins cannot access start/stop endpoints. | P0 | Backend |
| FR-009 | Masquerade behavior must apply across both controller and LiveView paths (not just one rendering mode). | P1 | Backend |
| FR-010 | System feature flag must fully disable entry points and start/stop execution paths when off. | P0 | Backend |
| FR-011 | Architecture must define an extensible impersonation subject model so author masquerade can be added without redesigning core flow. | P1 | Backend |

## 7. Acceptance Criteria (Testable)
- AC-001 (FR-001, FR-010) — Given the acting feature flag is disabled, when a system admin opens `/admin/users/:user_id`, then no `Act as user` action is visible and start endpoints reject with forbidden/not found.
- AC-002 (FR-001, FR-008) — Given the feature flag is enabled, when a non-system-admin attempts to access act-as entry or start route, then access is denied.
- AC-003 (FR-002) — Given a system admin clicks `Act as user`, when confirmation screen renders, then title is `Act as <user name>` and email + independent learner status are visible with `Proceed` and `Cancel` controls.
- AC-004 (FR-003, FR-004) — Given admin confirms `Proceed`, when session is established, then `current_user` resolves as the target user while admin identity metadata remains available as masquerade metadata.
- AC-005 (FR-005) — Given masquerade is active, when any page is rendered, then a bright magenta border is visible around viewport and bottom bar displays `Acting as <User Name>` and a `Stop acting as user` button.
- AC-006 (FR-006) — Given masquerade is active, when admin clicks `Stop acting as user`, then masquerade metadata is removed, prior session state is restored, and UI chrome disappears.
- AC-007 (FR-007) — Given masquerade is started/stopped, when querying audit log, then one start event and one stop event exist with timestamps, admin actor identity, and target user identity.
- AC-008 (FR-009) — Given masquerade is active, when navigating across LiveView and controller routes, then authorization and rendered behavior align with the target user account context.
- AC-009 (FR-011) — Given impersonation core modules, when reviewing APIs and schema/contracts, then subject type is not hard-coded to user-only internals (supports future `author` subject addition).

## 8. Non-Functional Requirements
- Performance & Scale:
  - Start/stop operations must complete within 250ms p95 server-side (excluding network).
  - Per-request masquerade context resolution adds <2ms p95 overhead.
  - No additional DB queries on steady-state requests beyond existing current user lookup.
- Reliability:
  - Stop action is idempotent.
  - Session restoration is deterministic when pre-masquerade user session exists or is nil.
  - If target user cannot be loaded at start time, masquerade is not started and no partial session state remains.
- Security & Privacy:
  - Only system admins can initiate/terminate masquerade.
  - Masquerade metadata in session must be server-side trusted only.
  - No PII beyond existing audit log norms; include IDs and email only where policy permits.
- Compliance:
  - Audit records must capture start/end with who/when/target details.
  - UI additions must meet WCAG 2.1 AA.
- Observability:
  - Emit telemetry on start, stop, deny, and invalid-session recovery paths.
  - Log structured warnings for invalid/expired masquerade state.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - Extend audit event enum list in `Oli.Auditing.LogEvent` with masquerade start/stop event types.
  - No new primary business tables required for v1.
- Context Boundaries:
  - `OliWeb.Users.UsersDetailView` / actions: entry point.
  - New masquerade web flow module(s) under `OliWeb` for confirm/start/stop.
  - `OliWeb.UserAuth` integration for effective user resolution.
  - `Oli.Auditing` for start/stop capture.
  - `Oli.Features` system-level flag gate.
- APIs / Contracts:
  - Start contract: `(admin_author, target_user, session)` -> updated session with masquerade metadata + user auth token.
  - Stop contract: `(admin_author, session)` -> restored session + stop audit.
  - Masquerade metadata must include admin actor ID and target subject type/ID.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| System Admin (author) | View act-as action, confirm, proceed, stop masquerade | Requires system feature flag enabled |
| Account Admin (non-system) | None | Explicitly forbidden even with account admin rights |
| Content Admin (non-system) | None | Explicitly forbidden |
| Standard Author | None | Explicitly forbidden |
| User (student/instructor) | None | No access to admin entry points |

## 10. Integrations & Platform Considerations
- LTI 1.3:
  - No launch contract change; masquerade only affects server-side authenticated actor resolution after login.
- GenAI (if applicable):
  - Not directly impacted; existing feature behavior should follow effective user context.
- External services:
  - No new external service integrations.
- Caching/Perf:
  - Session-only masquerade state; avoid introducing distributed cache requirements in v1.
- Multi-tenancy:
  - Masquerade must not bypass institution/section authorization checks for target user; effective access must remain what target user already has.

## 11. Feature Flagging, Rollout & Migration
- System-level feature flag:
  - Add a new global/system feature in `Oli.Features` (e.g., `admin-act-as-user`) default `disabled` in production.
- Gating rules:
  - Hide UI action when flag is off.
  - Hard-block start/stop endpoints when flag is off.
- Rollout plan:
  - Stage 1: Enable in dev for internal QA.
  - Stage 2: Enable in staging and validate audit + UI chrome + stop restoration.
  - Stage 3: Enable in production for system admins only.
- Rollback:
  - Disable feature flag; active masquerade sessions are forced to stop on next request.
- Migration:
  - No data backfill; only code-level feature registration and audit event type support.

## 12. Analytics & Success Metrics
- KPIs:
  - Median time-to-reproduce user issue by support/admin workflows decreases by 30%.
  - 100% of masquerade starts have matching stop audit events for explicit stop/logout paths.
  - Zero unauthorized masquerade starts.
- Events:
  - `masquerade.started`: admin_author_id, target_subject_type, target_subject_id.
  - `masquerade.stopped`: admin_author_id, target_subject_type, target_subject_id, duration_seconds.
  - `masquerade.denied`: reason (`flag_disabled`, `not_system_admin`, `invalid_target`).

## 13. Risks & Mitigations
- Privilege leakage risk (admin powers visible while acting) -> enforce effective-user authorization path precedence during masquerade and add integration tests.
- Missing stop audits on abnormal session termination -> add stop capture in explicit stop and logout paths; document residual edge case for hard session expiry.
- Confusion between real vs acting session -> persistent magenta chrome and explicit acting copy across views.
- Session restoration bugs -> store original session keys explicitly and test nil/non-nil original user-session variants.

## 14. Open Questions & Assumptions
- Assumptions:
  - Acting is initiated from admin author session and may occur even if no pre-existing `current_user` session exists.
  - Existing audit log schema accepts new event types without DB schema changes.
  - UI chrome can be injected through shared root/layout templates used by both LiveView and controller-rendered pages.
- Open Questions:
  - Should forced timeout/expiry of masquerade be added in v1 (e.g., 60-minute max duration) or deferred?
  - Should stop events include reason taxonomy (`manual_stop`, `logout`, `flag_disabled`) as required fields?

## 15. Timeline & Milestones (Draft)
- Milestone 1: PRD/FDD approved and feature flag defined.
- Milestone 2: Start/confirm/stop flow implemented with audit logging.
- Milestone 3: Global masquerade chrome + cross-layout behavior validated.
- Milestone 4: QA/security signoff and staged rollout.

## 16. QA Plan
- Automated:
  - LiveView tests for user detail action visibility and confirmation flow.
  - Controller tests for start/stop authorization, feature-flag gating, session writes/restoration.
  - Integration tests spanning controller and LiveView routes while masquerading.
  - Audit tests asserting start/stop events and payloads.
- Manual:
  - End-to-end admin flow from `/admin/users/:user_id` -> confirm -> acting -> stop.
  - Accessibility checks for keyboard focus order, button labels, and contrast of magenta chrome.
  - Negative tests: non-system admin attempt, flag disabled attempt, deleted user target.
- Performance Verification:
  - Measure p95 start/stop latency and p95 request overhead in local/staging with telemetry traces.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)
