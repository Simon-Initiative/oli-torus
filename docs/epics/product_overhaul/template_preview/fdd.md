# Template Preview — Functional Design Document

## 1. Executive Summary
This design adds a Template Overview preview action that launches the real student delivery home for the template-backed section instead of rendering a parallel preview surface. The implementation keeps the feature in existing Product/Template overview boundaries and reuses canonical delivery routes under `/sections/:section_slug`. On preview launch, the backend ensures the acting user has an enrolled learner record in that section, creating or reactivating it when missing. Enrollment writes are idempotent by relying on existing uniqueness constraints and an explicit upsert flow, so repeated preview clicks never create duplicate enrollments. Authorization remains server-side and reuses current template access checks already enforced by product/template mount logic. The launch opens in a new browser tab/window to preserve authoring context in the originating tab. No schema or migration changes are required because current enrollment and enrollment-role tables already provide the needed integrity constraints. Observability adds preview lifecycle telemetry and AppSignal tags so we can track launch success, latency, and enrollment-create versus enrollment-reuse outcomes. Security posture remains tenant-scoped by validating section ownership and user authorization before any enrollment mutation. Rollout uses standard deployment with no feature flag (per PRD), guarded by focused integration and LiveView regression coverage.

## 2. Requirements & Assumptions
- Functional Requirements:
  - `FR-001`: Show preview action only for authorized template managers in Template Overview (`OliWeb.Workspaces.CourseAuthor.Products.DetailsLive`, `OliWeb.Sections.Mount`).
  - `FR-002`: Resolve template-backed section and enforce tenant scoping before launch.
  - `FR-003`: Ensure student enrollment exists (create/reactivate when absent).
  - `FR-004`: Keep author/admin authoring context while enabling student-view launch.
  - `FR-005`: Launch canonical student home route for the resolved section.
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
  - A usable delivery user identity is available in session context (`socket.assigns.current_user`) for authors/admins using template preview.
  - Existing enrollment constraints (`index_user_section`, unique `enrollments_context_roles`) are present in all supported environments.
  - No feature flag is required for this ticket scope.

## 3. Torus Context Summary
- What we know:
  - Product/Template overview entrypoint is `OliWeb.Workspaces.CourseAuthor.Products.DetailsLive` and currently renders actions through `OliWeb.Products.Details.Actions`.
  - Authorization for product/template access already flows through `OliWeb.Sections.Mount.for/2` and enforces blueprint ownership/admin checks.
  - Student delivery home route is already canonical at `live("/", Delivery.Student.IndexLive)` under `scope "/sections/:section_slug"` with enrollment enforcement via `OliWeb.LiveSessionPlugs.RequireEnrollment`.
  - Enrollment persistence already has uniqueness guarantees:
    - `enrollments` unique index on `[:user_id, :section_id]` (`index_user_section`).
    - unique index on `enrollments_context_roles[:enrollment_id, :context_role_id]`.
  - Existing `Oli.Delivery.Sections.enroll/4` pathways already create/update enrollment plus context roles and are used in adjacent flows.
  - Design docs confirm section-as-delivery ontology and publication/resource invariants (`guides/design/high-level.md`, `guides/design/publication-model.md`, `guides/design/page-model.md`).
- Unknowns to confirm:
  - Expected UX when an author has no linked/current delivery `User` session: hard failure vs guided remediation.
  - Whether launch target should always be `"/sections/:slug"` for v1 or support deeper remembered destinations later.
  - Final telemetry naming convention alignment with existing product-overhaul dashboards.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- `OliWeb.Workspaces.CourseAuthor.Products.DetailsLive`:
  - Hosts the Preview action in the existing Actions block.
  - Supplies product/template context and authorization-gated rendering.
- `OliWeb.Products.Details.Actions`:
  - Adds `Preview` affordance with loading/disabled state support and descriptive help text.
- New service module: `Oli.Delivery.TemplatePreview`:
  - `prepare_launch(product_section, actor_user, actor_author)` orchestrates:
    - section/type/tenant validation,
    - learner-enrollment ensure (create/reactivate/reuse),
    - launch payload return (domain data only).
  - Returns `{:ok, %{section_slug: binary(), enrollment_outcome: :created | :reused}} | {:error, reason}`.
- Enrollment helper in `Oli.Delivery.Sections` (new function):
  - `ensure_student_enrollment(user_id, section_id)` with idempotent semantics for learner role.
  - Explicitly preserves uniqueness and can reactivate suspended enrollment to `:enrolled`.
- Delivery reuse:
  - Launch target remains `/sections/:section_slug` (canonical student home), but path construction is owned by `OliWeb` (`~p"/sections/#{section.slug}"`) to keep router concerns out of delivery context modules.

### 4.2 State & Message Flow
1. Authorized author/admin opens Template Overview (`Products.DetailsLive`).
2. User clicks `Preview` action.
3. LiveView invokes `TemplatePreview.prepare_launch/3`.
4. Service validates section is a template-backed section and actor is authorized in current tenant.
5. Service ensures learner enrollment idempotently (`created` or `reused`).
6. Service returns launch payload (`section_slug`, `enrollment_outcome`) without building URLs.
7. LiveView builds canonical launch path (`~p"/sections/#{section_slug}"`), triggers client-side launch in a new tab/window, and restores ready UI state.
8. New tab loads `/sections/:section_slug`, where existing plugs (`RequireEnrollment`, paywall, survey, etc.) continue enforcing runtime policy.

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
- Optional internal route addition (if chosen over push-event launch):
  - `GET /workspaces/course_author/:project_id/products/:product_id/preview`
  - Purpose: perform server-side prepare-launch then redirect (302) to `/sections/:section_slug`.

### 5.2 LiveView
- `OliWeb.Workspaces.CourseAuthor.Products.DetailsLive`:
  - New event: `"template_preview"`.
  - New assigns: `:preview_launching?`, `:preview_error`.
  - Behavior:
    - on event, call `TemplatePreview.prepare_launch/3`.
    - on success, build launch path in LiveView (`~p"/sections/#{section_slug}"`) and dispatch browser new-tab launch.
    - on error, render actionable message and re-enable action.
- `OliWeb.Products.Details.Actions`:
  - Add `Preview` button wired to parent `phx-click="template_preview"`.
  - Accessibility: clear label, disabled semantics during in-flight state.

### 5.3 Processes
- No new GenServer/Task/Registry process is required.
- DB writes occur inside request process with transactional boundaries in enrollment ensure helper.

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
- Preview launch always resolves fresh enrollment state from DB for correctness.

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
- Missing/invalid actor user identity:
  - Return typed error (`:missing_delivery_identity`) with remediation guidance; no writes.
- Enrollment ensure fails (DB/constraint):
  - Surface error, log structured context, emit failure telemetry.
- Launch dispatch fails client-side (popup blocked):
  - Show manual open link as fallback without rerunning enrollment mutation.
- Section no longer active/accessible:
  - Return `:section_unavailable` and avoid launch.

## 11. Observability
- Telemetry events:
  - `[:oli, :template_preview, :requested]`
  - `[:oli, :template_preview, :enrollment_ensured]`
  - `[:oli, :template_preview, :launch_succeeded]`
  - `[:oli, :template_preview, :launch_failed]`
- Measurements:
  - `duration` (native monotonic), `count`.
- Metadata:
  - `section_id`, `section_slug`, `product_id`, `user_id`, `author_id`, `tenant_id`, `enrollment_outcome`, `error_category`.
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
- Integration tests (context/controller/LiveView as implemented):
  - First preview creates learner enrollment and returns launch URL.
  - Subsequent preview reuses enrollment and does not create duplicates.
  - Unauthorized users cannot invoke preview launch.
  - Missing delivery user identity returns deterministic error and no DB mutation.
- LiveView tests:
  - Preview action visibility by role.
  - In-flight disable and error/success feedback behavior.
- Observability tests:
  - Assert telemetry event emission and metadata hygiene.
- Manual QA:
  - Validate new-tab launch to student home.
  - Validate parity with true student delivery for same template section.
  - Validate keyboard-only operation and focus continuity.

## 14. Backwards Compatibility
- No changes to existing delivery URL contracts.
- No schema/migration changes, so no data migration risk.
- Existing template overview actions remain unchanged except for additive Preview action.
- Existing enrollment flows continue to function; new helper is additive and scoped.

## 15. Risks & Mitigations
- Risk: Some authors may lack a linked/current delivery user identity.
  - Mitigation: explicit precondition check with actionable guidance; track with telemetry for follow-up.
- Risk: Enrollment race condition under concurrent launches.
  - Mitigation: transactionally enforced idempotent upsert leveraging existing unique indexes.
- Risk: Popup blockers reduce perceived launch reliability.
  - Mitigation: direct user-action launch path plus fallback link UX.
- Risk: Authorization regression between template roles and delivery roles.
  - Mitigation: preserve existing Mount authorization and add explicit unauthorized regression tests.

## 16. Open Questions & Follow-ups
- Should we enforce a hard requirement that `current_user` exists for preview, or implement a deterministic author->user resolution helper for missing sessions?
- Do we want a dedicated lightweight preview redirect endpoint (server 302) to maximize popup compatibility, or keep launch dispatch fully inside LiveView JS events?
- Should preview telemetry be integrated into an existing Product Overhaul dashboard or a new template-preview-specific dashboard?

## 17. References
- `docs/epics/product_overhaul/template_preview/prd.md`
- `docs/epics/product_overhaul/overview.md`
- `docs/epics/product_overhaul/prd.md`
- `guides/design/high-level.md`
- `guides/design/publication-model.md`
- `guides/design/page-model.md`
- `lib/oli_web/live/workspaces/course_author/products/details_live.ex`
- `lib/oli_web/live/products/details/actions.ex`
- `lib/oli_web/live/sections/mount.ex`
- `lib/oli_web/router.ex`
- `lib/oli_web/live_session_plugs/require_enrollment.ex`
- `lib/oli/delivery/sections.ex`
- `lib/oli/delivery/sections/enrollment.ex`
- `priv/repo/migrations/20200310193550_init_core_schemas.exs`
- `priv/repo/migrations/20240719181530_enrollments_context_roles_unique_index.exs`
