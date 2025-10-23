# Admin Panel Design Alignment — FDD

## 1. Executive Summary

Admin workspace alignment will move every `/admin/**` and `/authoring/communities/**` route onto the modern Phoenix LiveView workspace shell so administrators and community managers experience consistent navigation, theming, and breadcrumbs. An `Admin` workspace entry becomes visible for all admin-role users and remains active across admin and community paths while preserving the existing community sub-navigation. Legacy controller renders (ingest/report flows) are wrapped in the shared layout after supplying the assigns their templates expect, removing the last dependency on the old admin layout. Because the refresh ships without a feature flag, rollout depends on thorough staging validation and a fast revert path. Performance mirrors authoring workspaces (p50 render ≤ 800 ms, p95 patch ≤ 400 ms) with CSS payload growth held under 50 KB gz. Telemetry sent to AppSignal tracks nav clicks and breadcrumb usage, giving Ops insight into adoption. Primary risks involve LiveDashboard compatibility, maintaining the community navigation look-and-feel, and ensuring controller assigns are complete; prototypes, regression tests, and targeted QA mitigate these.

## 2. Requirements & Assumptions

- **Functional Requirements**
  - FR-001: Render the `Admin` workspace nav entry only for authenticated admin users, including while visiting `/authoring/communities/**`.
  - FR-002: Maintain active nav styling for all `/admin/**` and `/authoring/communities/**` routes (LiveViews, controllers, LiveDashboard).
  - FR-003: Clicking the `Admin` nav pushes a navigation to `/admin` without page reload.
  - FR-004: All admin and community pages render via the shared workspace layout; ingest/report controllers receive required assigns.
  - FR-005: Use the shared breadcrumb component wherever breadcrumbs already exist; inject only a minimal `Admin` crumb when none did previously.
  - FR-006: Match authoring workspace light/dark theming for admin and community screens.
- **Non-Functional Requirements**
  - Initial LiveView render p50 ≤ 800 ms, p95 ≤ 1.5 s; LiveView patch p95 ≤ 400 ms.
  - Additional CSS/JS payload ≤ 50 KB gzipped.
  - LiveView error rate ≤ 0.5 %.
  - WCAG 2.1 AA compliance (focus order, aria attributes, contrast).
- **Explicit Assumptions**
  - Admin routes remain under `/admin/**`; community management stays under `/authoring/communities/**`.
  - Existing `Oli.Accounts` role checks remain authoritative; no new permission model changes.
- LiveDashboard and other admin-support tools (even when served outside `/admin/**`) must surface the shared workspace chrome so the `Admin` nav entry remains visible and active; if full embedding fails, the fallback still renders the workspace nav frame.
  - Community views keep their current navigation markup; only outer layout and workspace state integrate with the shared shell.

## 3. Torus Context Summary

Modern workspace experiences rely on `lib/oli_web/components/layouts/workspace.html.heex` and helpers in `lib/oli_web/components/delivery/layouts.ex`, while admin routes still consume the legacy layout in `lib/oli_web/templates/layout/workspace.html.heex`. Admin LiveViews (for example `lib/oli_web/live/admin/admin_view.ex` and `lib/oli_web/live/features/features_live.ex`) already populate breadcrumbs through `OliWeb.Common.Breadcrumb`. Community management routes live under `/authoring/communities` with authorization plugs (`:community_admin`, `:require_authenticated_account_admin`) and bespoke navigation components. Sidebar state and active workspace metadata are assigned by `OliWeb.LiveSessionPlugs.AssignActiveMenu` and `SetSidebar`, but these currently apply only to `/workspaces/**` flows. Ingest/report controllers render templates that expect assigns such as `breadcrumbs`, `ctx`, and `active` flags. Telemetry and dark-mode toggles are handled by components inside `OliWeb.Components.Delivery`.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

Create an `:admin_workspace` live_session that wraps all admin LiveViews and ensures `root_layout: {OliWeb.LayoutView, :delivery}` and `layout: {OliWeb.Layouts, :workspace}`. Apply the same live_session (or companion plug) to `/authoring/communities/**` routes so they inherit the workspace shell while retaining their existing sub-navigation modules. Extend `OliWeb.Components.Delivery.Layouts.workspace_sidebar_nav/1` to render an `Admin` nav entry for admin-role users, mark it active when URIs match admin or community prefixes, and handle clicks via LiveView events (`push_navigate(~p"/admin")`). Update `OliWeb.LiveSessionPlugs.AssignActiveMenu` to detect modules under `OliWeb.Admin` and community namespaces, deriving `active_workspace: :admin` and stable `active_view` atoms without altering community-specific nav. Adjust `OliWeb.LiveSessionPlugs.SetSidebar` so workspace extraction recognizes `/admin/**` and `/authoring/communities/**`, preventing redundant LiveView reconnects after sidebar toggles. Maintain existing breadcrumb lists where they exist; when absent, inject a single crumb for `/admin`.

### 4.2 State & Message Flow

`OliWeb.LiveSessionPlugs.SetCtx` continues to assign `ctx` for account menus and theming. The new live_session ensures admin and community pages assign `active_workspace: :admin`, optional `active_view`, and minimal breadcrumbs. Sidebar state remains URL-driven (`sidebar_expanded` param); `SetSidebar` now treats admin/community routes as the same workspace so toggles patch instead of reconnecting. Navigation clicks emit telemetry (`workspace_nav_clicked`) before performing `push_navigate` to `/admin`. Breadcrumb interactions reuse existing LiveView handlers; minimal crumbs avoid altering current community navigation.

### 4.3 Supervision & Lifecycle

No new OTP processes are introduced. Admin and community LiveViews still operate under the Phoenix endpoint supervisor. Controller actions (ingest/report) wrap responses in the shared layout via helper functions that build the assigns they require, ensuring lifecycle consistency. Telemetry attaches to existing AppSignal handlers; failures are isolated and do not affect LiveView supervision.

### 4.4 Alternatives Considered

- Incrementally restyling legacy layout without swapping to the shared workspace shell was rejected because it fails theming and navigation consistency requirements.
- Rebuilding admin/community management as a separate SPA was deemed overly disruptive and inconsistent with Torus’s LiveView-first strategy.
- Feature-flagging the new layout was removed per requirement updates; instead, quality assurance and a straightforward rollback plan cover deployment risks.

## 5. Interfaces

### 5.1 HTTP/JSON APIs

No new external APIs are introduced. Controller actions under ingest/report routes use helpers to set `@breadcrumbs`, `@ctx`, `@active_workspace`, and other expected assigns before calling `render_layout "workspace.html"` so templates render inside the shared shell.

### 5.2 LiveView

Admin and community LiveViews assign `active_workspace: :admin` and, where appropriate, `active_view` atoms derived from module names. They expose breadcrumbs exactly as before; when none were provided, the layout helper adds a root `Admin` crumb. A new `handle_event("workspace_nav_clicked", %{"target" => "admin"})` emits telemetry and navigates to `/admin`. Community LiveViews continue to render their existing navigation components unchanged.

### 5.3 Processes

No new GenServers or background pipelines are required. Telemetry events use the existing AppSignal attachment point.

## 6. Data Model & Storage

No schema or migration changes are necessary. Route-level assigns remain transient. Helpers may query existing contexts (for example, to populate ingest options) using current APIs; no new indexes are required.

## 7. Consistency & Transactions

The design introduces no new transactional flows. Controller helpers use existing contexts for reads and respect current transactional boundaries. Navigation state is entirely client-side and stateless.

## 8. Caching Strategy

No additional caching layers are introduced. Existing ETS caches for authors and session context continue to serve admin/community routes. Controller helpers rely on current caching behavior in their contexts.

## 9. Performance and Scalability Plan

- **Budgets**: initial render p50 ≤ 800 ms, p95 ≤ 1.5 s, p99 ≤ 2.2 s; LiveView patch p95 ≤ 400 ms; Repo pool utilization ≤ 80 % under 200 concurrent admin/community sessions; added CSS ≤ 50 KB gz.
- **Load Tests**: Run a k6 scenario alternating `/admin`, `/admin/users`, `/authoring/communities`, `/admin/ingest/upload`, including sidebar toggles and pagination. Fail if p95 render > 1.5 s or LiveView error rate > 0.5 %.
- **Hotspots & Mitigations**: Prototype LiveDashboard embedding early; if incompatible, implement a fallback wrapper that still renders the shared workspace chrome (sidebar + Admin nav) around the tool. Preserve community nav markup to avoid regressions, and remove legacy CSS to keep payload minimal.

## 10. Failure Modes & Resilience

Missing controller assigns will raise errors early; helpers include unit tests and logs to catch gaps. Breadcrumb absence falls back to the minimal crumb without breaking navigation. If LiveDashboard cannot be embedded, the fallback still renders the shared workspace chrome so the Admin nav remains available while legacy content loads. Telemetry failures are isolated by the `:telemetry` infrastructure.

## 11. Observability

- Telemetry events: `[:oli, :admin_workspace, :nav_click]` with metadata `{user_id, institution_id, from, to, route_type}`; `[:oli, :admin_workspace, :breadcrumb_use]` when breadcrumbs are followed.
- Structured logs: `info` log on layout mount with `%{workspace: :admin, module: socket.view}`.
- AppSignal dashboards updated to chart nav click counts, latency, and error ratio; alert when nav click error ratio exceeds 0.5 % or latency breaches SLOs.

## 12. Security & Privacy

Existing router plugs (`:require_authenticated_admin`, `:community_admin`, `:require_authenticated_account_admin`) remain in place. The `Admin` nav is rendered only when `Accounts.is_admin?/1` or equivalent role checks succeed. Breadcrumb and telemetry metadata exclude PII beyond existing IDs. All routes continue to respect tenant scoping enforced by current contexts.

## 13. Testing Strategy

- LiveView tests verifying admin nav visibility and active state on `/admin/**` and `/authoring/communities/**`, breadcrumb rendering (including minimal crumb), dark-mode styling, and sidebar toggle behavior.
- Controller integration tests ensuring ingest/report actions render with the new layout and required assigns.
- Accessibility audits (axe) on admin dashboard, users index, community index, and ingest upload pages.
- Visual regression snapshots for key admin/community pages in light and dark themes.
- Telemetry unit tests asserting `nav_click` events fire with the correct metadata.

## 15. Risks & Mitigations

| Risk | Mitigation |
| --- | --- |
| LiveDashboard cannot be wrapped cleanly | Prototype early; supply a fallback wrapper that preserves the shared workspace chrome (Admin nav + breadcrumbs) even if the inner content uses legacy layout. |
| Community navigation regresses | Preserve existing nav templates, add regression tests, and perform targeted QA walkthroughs. |
| Controller helpers omit required assigns | Centralize helper logic, cover with tests, log warnings in staging, and document required assigns. |
| Lack of feature flag complicates rollback | Rely on staging soak tests and keep a revert-ready branch; pair launch with close monitoring. |

## 16. Open Questions & Follow-ups

- Confirm which community subroutes need minimal breadcrumbs versus none.
- Validate ingest/report templates work with LiveView-compatible assigns and do not require direct `conn` mutations.
- Decide whether the fallback crumb label should read “Admin” or “Communities” on community-only pages if product prefers different wording.

## 17. References

- Phoenix LiveView Layouts · https://hexdocs.pm/phoenix_live_view/layouts.html · Accessed 2025‑02‑23  
- Phoenix Router Pipelines · https://hexdocs.pm/phoenix/routing.html#pipelines · Accessed 2025‑02‑23  
- AppSignal Telemetry for Elixir · https://docs.appsignal.com/elixir/instrumentation/telemetry.html · Accessed 2025‑02‑23  
- Tailwind CSS Dark Mode · https://tailwindcss.com/docs/dark-mode · Accessed 2025‑02‑23
