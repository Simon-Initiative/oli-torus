# Template Preview — Functional Design Document

## 1. Executive Summary
This design adds a Template Overview preview action that launches the real student delivery home for the template-backed section instead of rendering a parallel preview surface. The implementation keeps the feature in existing Product/Template overview boundaries and reuses canonical delivery routes under `/sections/:section_slug`. On preview launch, the backend ensures the acting user has an enrolled learner record in that section when a delivery `current_user` is present, creating or reactivating it when missing. When preview is initiated from an authorized author/admin session without a logged-in delivery user, the backend instead creates or reuses the section's singleton hidden instructor account, following the existing admin section-access pattern so preview can launch without an extra learner-login decision. Enrollment and hidden-instructor writes are idempotent by relying on existing uniqueness constraints and explicit helper flows, so repeated preview clicks never create duplicate learner enrollments or multiple hidden instructor identities for the same section. Authorization remains server-side and reuses current template access checks already enforced by product/template mount logic. The launch opens in a new browser tab/window to preserve authoring context in the originating tab. No schema or migration changes are required because current enrollment, enrollment-role, and hidden-user access patterns already provide the needed integrity constraints. Observability adds preview lifecycle telemetry and AppSignal tags so we can track launch success, latency, learner-enrollment create/reuse, and hidden-instructor create/reuse outcomes. Security posture remains tenant-scoped by validating section ownership and user authorization before any enrollment mutation. Rollout uses standard deployment with no feature flag (per PRD), guarded by focused integration and LiveView regression coverage.

## 2. Requirements & Assumptions
- Functional Requirements:
  - `FR-001`: Show preview action only for authorized template managers in Template Overview (`OliWeb.Workspaces.CourseAuthor.Products.DetailsLive`, `OliWeb.Sections.Mount`).
  - `FR-002`: Resolve template-backed section and enforce tenant scoping before launch.
  - `FR-003`: Ensure student enrollment exists (create/reactivate when absent).
  - `FR-004`: Keep author/admin authoring context while enabling student-view launch.
  - `FR-005`: When `current_user` is absent, create or reuse the section-scoped singleton hidden instructor account and use it for preview access.
  - Canonical launch destination remains the resolved section delivery home.
  - `FR-006`: Repeated launches do not create duplicate enrollment rows.
  - `FR-007`: Deterministic error handling with no partial/duplicate writes.
  - `FR-008`: Emit telemetry for request, enrollment outcome, and launch result.
- Non-Functional Requirements:
  - Launch preparation p95 <= 700ms (auth + section resolve + enrollment ensure + URL generation).
  - Zero duplicate enrollments for `(user_id, section_id)` from preview flow.
  - Preview launch failure rate <= 1% excluding browser popup-block outcomes.
  - Server-side authorization and tenant scoping on every preview request.
  - WCAG AA-compliant action affordance and status feedback in Template Overview.
- Explicit Assumptions:
  - Template entities are `sections.type == :blueprint` and can be previewed through standard delivery student home (`/sections/:section_slug`).
  - When `current_user` is absent, the existing hidden-instructor access model can be reused and extended from admin-only usage to authorized template authors for preview launches.
- Existing enrollment constraints (`index_user_section`, unique `enrollments_context_roles`) are present in all supported environments.
- No feature flag is required for this ticket scope.

## Requirements Traceability

- Source of truth: `docs/exec-plans/current/epics/product_overhaul/template_preview/requirements.yml`
- FDD verification command:
  - `python3 .agents/skills/spec_requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/product_overhaul/template_preview --action verify_fdd`
- Stage gate command:
  - `python3 .agents/skills/spec_requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/product_overhaul/template_preview --action master_validate --stage fdd_only`

## 3. Torus Context Summary
- What we know:
  - Product/Template overview entrypoint is `OliWeb.Workspaces.CourseAuthor.Products.DetailsLive` and currently renders actions through `OliWeb.Products.Details.Actions`.
  - Authorization for product/template access already flows through `OliWeb.Sections.Mount.for/2` and enforces blueprint ownership/admin checks.
  - Student delivery home route is already canonical at `live("/", Delivery.Student.IndexLive)` under `scope "/sections/:section_slug"` with enrollment enforcement via `OliWeb.LiveSessionPlugs.RequireEnrollment`.
  - Enrollment persistence already has uniqueness guarantees:
    - `enrollments` unique index on `[:user_id, :section_id]` (`index_user_section`).
    - unique index on `enrollments_context_roles[:enrollment_id, :context_role_id]`.
  - Existing `Oli.Delivery.Sections.enroll/4` pathways already create/update enrollment plus context roles and are used in adjacent flows.
  - Design docs confirm section-as-delivery ontology and publication/resource invariants (`docs/design-docs/high-level.md`, `docs/design-docs/publication-model.md`, `docs/design-docs/page-model.md`).
- Unknowns to confirm:
  - Whether launch target should always be `"/sections/:slug"` for v1 or support deeper remembered destinations later.
  - Final telemetry naming convention alignment with existing product-overhaul dashboards.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- `OliWeb.Workspaces.CourseAuthor.Products.DetailsLive`:
  - Hosts the Preview action in the existing Actions block.
  - Supplies product/template context and authorization-gated rendering.
- `OliWeb.Products.Details.Actions`:
  - Adds `Preview` affordance with loading/disabled state support and descriptive help text.
- `OliWeb.Workspaces.Instructor.IndexLive`:
  - Surfaces the currently active hidden delivery account and logout control whenever `current_user.hidden == true`, regardless of whether that hidden session originated from admin section access or template preview fallback.
- New service module: `Oli.Delivery.TemplatePreview`:
  - `prepare_launch(product_section, actor_user, actor_author)` orchestrates:
    - section/type/tenant validation,
    - learner-enrollment ensure (create/reactivate/reuse) when `actor_user` exists,
    - hidden-instructor ensure (create/reuse) when `actor_user` is absent and `actor_author` is authorized,
    - launch payload return (domain data only).
  - Returns `{:ok, %{section_slug: binary(), launch_identity: :current_user | :hidden_instructor, enrollment_outcome: :created | :reused | nil, hidden_instructor_outcome: :created | :reused | nil}} | {:error, reason}`.
- Enrollment helper in `Oli.Delivery.Sections` (new function):
  - `ensure_student_enrollment(user_id, section_id)` with idempotent semantics for learner role.
  - Explicitly preserves uniqueness and can reactivate suspended enrollment to `:enrolled`.
- Hidden instructor helper reuse:
  - Reuse `Oli.Delivery.Sections.fetch_hidden_instructor/1` semantics as the section-scoped singleton hidden instructor provisioner.
  - Extend/wrap it as needed so preview launch can distinguish `:created` versus `:reused` outcomes for telemetry and testing.
- Delivery reuse:
  - Launch target remains `/sections/:section_slug` (canonical student home), but a server redirect/session-establishing handoff is required for the hidden-instructor fallback so the launched tab receives the correct user session before entering delivery.
  - Because hidden instructor login state is stored in the normal browser user session, that state persists after preview/admin section access until replaced or explicitly logged out.

### 4.2 State & Message Flow
1. Authorized author/admin opens Template Overview (`Products.DetailsLive`).
2. User clicks `Preview` action.
3. LiveView invokes `TemplatePreview.prepare_launch/3`.
4. Service validates section is a template-backed section and actor is authorized in current tenant.
5. If `current_user` exists, service ensures learner enrollment idempotently (`created` or `reused`).
6. If `current_user` is absent, service creates or reuses the section-scoped hidden instructor singleton (`created` or `reused`).
7. Service returns launch payload describing the launch identity and section slug.
8. LiveView launches a server-owned redirect/session handoff URL in a new tab/window and restores ready UI state.
9. The handoff establishes the chosen preview identity in the launched tab, then redirects to `/sections/:section_slug`, where existing plugs (`RequireEnrollment`, paywall, survey, etc.) continue enforcing runtime policy for learner launches and existing hidden-instructor access behavior for fallback launches.
10. Template preview delivery renders a `Preview Mode` header strip with an `Exit Preview` action.
11. `Exit Preview` always clears the template-preview session markers and, when the launched identity is a hidden instructor, also logs that hidden user out of the browser session before returning to authoring.
12. If a hidden instructor session still remains active after preview/admin section access, users can also reset it from Instructor Workspace via the hidden delivery-account logout control before launching a different section/template.

Backpressure and concurrency notes:
- Concurrent double-clicks are tolerated by enrollment uniqueness constraints and role upsert idempotency.
- UI disables repeated clicks while request is in-flight to reduce unnecessary write pressure.

### 4.3 Supervision & Lifecycle
- No new long-lived OTP processes are required.
- Flow executes synchronously in LiveView request lifecycle; no Oban worker needed.
- Failure isolation:
  - Enrollment/authorization errors are surfaced as flash/status without mutating unrelated state.
  - Existing delivery and enrollment plugs remain untouched, minimizing blast radius.

### 4.4 Alternatives Considered
- Reuse instructor preview routes (`/sections/:slug/preview/...`) for template preview:
  - Rejected because this feature explicitly requires true student delivery parity, not instructor preview mode.
- Build a separate template preview rendering stack inside authoring:
  - Rejected due drift risk and duplicated permission/content logic.
- Launch directly without enrollment and rely on delivery redirect:
  - Rejected because it introduces non-deterministic UX and violates FR-003/FR-007 expectations.
- Background job for enrollment provisioning:
  - Rejected as unnecessary overhead for low-latency, click-driven interaction.

## 5. Interfaces
### 5.1 HTTP/JSON APIs
- No public API contract changes.
- No new external HTTP integrations.
- Required internal route/session handoff:
  - `GET /workspaces/course_author/:project_id/products/:product_id/preview_launch`
  - Purpose: establish the chosen preview identity in the launched tab, then redirect (302) to `/sections/:section_slug`.

### 5.2 LiveView
- `OliWeb.Workspaces.CourseAuthor.Products.DetailsLive`:
  - New event: `"template_preview"`.
  - New assigns: `:preview_launching?`, `:preview_error`.
  - Behavior:
    - on event, call `TemplatePreview.prepare_launch/3`.
    - on success, build server handoff path in LiveView and dispatch browser new-tab launch.
    - on error, render actionable message and re-enable action.
- `OliWeb.Products.Details.Actions`:
  - Add `Preview` button wired to parent `phx-click="template_preview"`.
  - Accessibility: clear label, disabled semantics during in-flight state.
- `OliWeb.ProductsController.preview_exit/2`:
  - Clears template preview session state.
  - If `current_user.hidden == true`, also logs out that hidden delivery account before redirecting back to the template overview return path.
- `OliWeb.Workspaces.Instructor.IndexLive`:
  - When `current_user.hidden == true`, render a lightweight hidden-delivery-account panel with account details and a `/users/log_out` action so users can manually clear persistent hidden instructor session state.

### 5.3 Processes
- No new GenServer/Task/Registry process is required.
- DB writes occur inside request process with transactional boundaries in learner-enrollment and hidden-instructor ensure helpers.

## 6. Data Model & Storage
### 6.1 Ecto Schemas
- No schema additions.
- No migrations.
- Existing tables used:
  - `enrollments` (unique `[:user_id, :section_id]`).
  - `enrollments_context_roles` (unique `[:enrollment_id, :context_role_id]`).
- Optional auditing extension (existing audit infrastructure): log preview launch attempts and outcomes.

### 6.2 Query Performance
- Expected query shape per launch:
  - section lookup by slug/id (already in assigns in overview path),
  - enrollment lookup/upsert by `(user_id, section_id)`,
  - learner role upsert by `(enrollment_id, context_role_id)`.
- Index posture is already sufficient for O(log n) lookup/upsert on unique keys.
- Guard against unnecessary repeated fetches by reusing `socket.assigns.product` as section context.

## 7. Consistency & Transactions
- Enrollment ensure operation uses a single transaction boundary:
  - upsert/reuse enrollment row,
  - ensure learner context role mapping,
  - normalize status to `:enrolled` when previously suspended.
- Idempotency:
  - Multiple calls for same `(user_id, section_id)` produce a single enrollment row.
  - Learner role association is inserted `on_conflict: :nothing`.
- Failure compensation:
  - Transaction rollback leaves no partial enrollment-role state.
  - Launch URL is only returned after successful enrollment ensure.

## 8. Caching Strategy
- No new cache layers.
- No SectionResourceDepot changes.
- Preview launch always resolves fresh enrollment or hidden-instructor state from DB for correctness.

## 9. Performance and Scalability Plan
### 9.1 Budgets
- Launch-prep p50 <= 250ms, p95 <= 700ms, p99 <= 1200ms under normal authoring load.
- Throughput expectation: low-frequency admin/author action; target 50 concurrent launches without saturation.
- Memory posture: constant-size request state; no long-lived buffers.

### 9.3 Hotspots & Mitigations
- Hotspot: rapid repeat-click causing redundant writes.
  - Mitigation: UI in-flight disable + DB-level uniqueness + idempotent upsert.
- Hotspot: enrollment race windows under concurrency.
  - Mitigation: transaction + conflict-safe inserts on enrollment-role association.
- Hotspot: launch blocked by browser popup policy.
  - Mitigation: launch from direct user action path and show fallback link/message on blocked outcome.

## 10. Failure Modes & Resilience
- Unauthorized user on template overview:
  - Preview action hidden and server-side event rejected.
- Missing/invalid actor identity:
  - If `current_author` is authorized and `current_user` is absent, create/reuse the hidden instructor singleton instead of failing.
  - Only return typed error when neither a valid learner identity nor an authorized hidden-instructor fallback can be established.
- Enrollment ensure fails (DB/constraint):
  - Surface error, log structured context, emit failure telemetry.
- Launch dispatch fails client-side (popup blocked):
  - Show manual open link as fallback without rerunning enrollment mutation.
- Section no longer active/accessible:
  - Return `:section_unavailable` and avoid launch.
- Hidden instructor session persists and user later targets a different section/template:
  - Do not create a second hidden identity type; continue reusing the section-scoped hidden instructor model.
  - Primary recovery path is `Exit Preview`, which clears hidden-user session state when preview is the source of that identity.
  - Instructor Workspace also exposes the hidden account/logout affordance as a manual recovery/reset path for sticky cross-section session state.

## 11. Observability
- Telemetry events:
  - `[:oli, :template_preview, :requested]`
  - `[:oli, :template_preview, :enrollment_ensured]`
  - `[:oli, :template_preview, :launch_succeeded]`
  - `[:oli, :template_preview, :launch_failed]`
- Measurements:
  - `duration` (native monotonic), `count`.
- Metadata:
  - `section_id`, `section_slug`, `product_id`, `user_id`, `author_id`, `tenant_id`, `launch_identity`, `enrollment_outcome`, `hidden_instructor_outcome`, `error_category`.
- AppSignal:
  - Tag feature area `template_preview` and outcome labels for alerting.
- Alert thresholds:
  - launch failure ratio > 1% over 15m,
  - p95 launch-prep latency > 700ms over 15m.

## 12. Security & Privacy
- AuthN/AuthZ:
  - Reuse existing author authentication and blueprint authorization (`Mount.for/2`).
  - Enforce server checks before any enrollment mutation.
- Tenant isolation:
  - Section context originates from authorized product/template scope; no cross-tenant section lookup path.
- PII handling:
  - Avoid sensitive payloads in telemetry/logs; use IDs and categorical errors only.
- Auditability:
  - Capture preview launch attempts/outcomes in existing auditing pipeline when enabled.

## 13. Testing Strategy
- Unit tests:
  - `TemplatePreview.prepare_launch/3` success and typed error paths.
  - `Sections.ensure_student_enrollment/2` create, reuse, suspended->enrolled reactivation, duplicate-call idempotency.
  - Hidden instructor helper/adapter create, reuse, and singleton-per-section behavior for no-`current_user` launches.
- Integration tests (context/controller/LiveView as implemented):
  - First preview creates learner enrollment and returns launch URL.
  - Subsequent preview reuses enrollment and does not create duplicates.
  - No-`current_user` preview creates hidden instructor once and reuses it on subsequent launches.
  - Unauthorized users cannot invoke preview launch.
  - Missing preview identity returns deterministic error only when both learner and hidden-instructor fallback establishment fail.
- LiveView tests:
  - Preview action visibility by role.
  - In-flight disable and error/success feedback behavior.
- Observability tests:
  - Assert telemetry event emission and metadata hygiene.
- Manual QA:
  - Validate new-tab launch to student home.
  - Validate parity with true student delivery for same template section.
  - Validate `Exit Preview` clears template preview session markers and logs out hidden instructor sessions created by preview fallback.
  - Validate hidden instructor session is visible in Instructor Workspace and can be cleared with the logout control after preview/admin section access.
  - Validate keyboard-only operation and focus continuity.

## 14. Backwards Compatibility
- No changes to existing delivery URL contracts.
- No schema/migration changes, so no data migration risk.
- Existing template overview actions remain unchanged except for additive Preview action.
- Existing enrollment flows continue to function; new helper is additive and scoped.

## 15. Risks & Mitigations
- Risk: Some authors may lack a logged-in delivery user identity.
  - Mitigation: create/reuse the section-scoped hidden instructor fallback and track create/reuse rates with telemetry.
- Risk: Enrollment race condition under concurrent launches.
  - Mitigation: transactionally enforced idempotent upsert leveraging existing unique indexes.
- Risk: Popup blockers reduce perceived launch reliability.
  - Mitigation: direct user-action launch path plus fallback link UX.
- Risk: Authorization regression between template roles and delivery roles.
  - Mitigation: preserve existing Mount authorization and add explicit unauthorized regression tests.

## 16. Open Questions & Follow-ups
- Do we want a dedicated lightweight preview redirect endpoint (server 302) to maximize popup compatibility, or keep launch dispatch fully inside LiveView JS events?
- Should preview telemetry be integrated into an existing Product Overhaul dashboard or a new template-preview-specific dashboard?

## 17. References
- `docs/exec-plans/current/epics/product_overhaul/template_preview/prd.md`

## Decision Log
### 2026-03-24 - Document Hidden Session Logout Handling
- Change: Clarified that hidden-instructor preview fallback uses persistent browser session state and that Instructor Workspace exposes the hidden delivery-account logout affordance for manual reset.
- Reason: Implementation now explicitly reuses sticky hidden instructor sessions and exposes the logout panel outside the admin-only placeholder branch.
- Evidence: `lib/oli_web/live/workspaces/instructor/index_live.ex`, `lib/oli/delivery/template_preview.ex`, `test/oli_web/live/workspaces/instructor_test.exs`
- Impact: Makes the session-lifecycle tradeoff and supported operator workflow explicit in interfaces, failure modes, and manual QA.
### 2026-03-24 - Document Exit Preview Hidden-User Cleanup
- Change: Added the explicit `Exit Preview` cleanup behavior for hidden-instructor launches.
- Reason: The implementation now uses `preview_exit/2` to clear preview markers and log out hidden users when preview was running under the hidden-instructor fallback.
- Evidence: `lib/oli_web/controllers/products_controller.ex`, `test/oli_web/controllers/products_controller_test.exs`
- Impact: Clarifies the primary cleanup path for hidden preview sessions in the runtime flow and QA expectations.
- `docs/exec-plans/current/epics/product_overhaul/overview.md`
- `docs/exec-plans/current/epics/product_overhaul/prd.md`
- `docs/design-docs/high-level.md`
- `docs/design-docs/publication-model.md`
- `docs/design-docs/page-model.md`
- `lib/oli_web/live/workspaces/course_author/products/details_live.ex`
- `lib/oli_web/live/products/details/actions.ex`
- `lib/oli_web/live/sections/mount.ex`
- `lib/oli_web/router.ex`
- `lib/oli_web/live_session_plugs/require_enrollment.ex`
- `lib/oli/delivery/sections.ex`
- `lib/oli/delivery/sections/enrollment.ex`
- `priv/repo/migrations/20200310193550_init_core_schemas.exs`
- `priv/repo/migrations/20240719181530_enrollments_context_roles_unique_index.exs`

## Decision Log
- 2026-03-18: Replaced the prior missing-`current_user` error path with an explicit hidden-instructor fallback requirement. FDD now treats hidden instructor creation/reuse as the no-user preview identity model, using one hidden instructor singleton per section.
