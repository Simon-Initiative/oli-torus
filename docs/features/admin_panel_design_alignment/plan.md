# Admin Panel Design Alignment — Delivery Plan

**Scope**

- Implements FR-001…FR-006 from `docs/features/admin_panel_design_alignment/prd.md` using the architecture in `docs/features/admin_panel_design_alignment/fdd.md`.
- Standardizes all `/admin/**` and `/authoring/communities/**` experiences on the shared workspace shell, navigation, breadcrumbs, and theming without changing underlying data workflows.
- Introduces telemetry, accessibility coverage, and documentation updates needed for rollout and support.

**Non-Functional Guardrails**

- LiveView render p50 ≤ 800 ms, p95 ≤ 1.5 s; patch p95 ≤ 400 ms.
- Additional CSS/JS payload ≤ 50 KB gzipped; eliminate legacy CSS that conflicts with the shared shell.
- LiveView error rate ≤ 0.5 %; maintain WCAG 2.1 AA conformance (focus order, ARIA, contrast).
- Preserve existing authorization boundaries (`Oli.Accounts` role checks) and tenant isolation; no unauthenticated exposure.
- Ship with AppSignal telemetry for nav clicks and breadcrumb usage; dashboards must surface admin adoption metrics.

**Clarifications & Assumptions**

- Product confirmed no runtime feature flag or kill switch is required; rollout proceeds unflagged as described in `fdd.md`.
- LiveDashboard and any other non-`/admin/**` admin tools must display the `Admin` menu and maintain the active nav state so admins can always navigate back to `/admin`.
- Breadcrumb copy will reuse existing gettext strings unless Product provides new labels.
- Community managers under `/authoring/communities/**` inherit the `Admin` workspace nav but retain their sub-navigation, per FDD Section 4.

---

## Phase 0: Route Audit & Design Alignment

**Goal** Catalog all admin/community entry points, confirm design tokens, and lock navigation expectations before code changes.

**Tasks**

- [x] Inventory current `/admin/**`, `/authoring/communities/**`, LiveDashboard, ingest, and report routes; document layout usages and breadcrumb coverage.
- [x] Validate design tokens, spacing, and theme artifacts against the mocks in `attachments/` with Design; note any gaps requiring new components.
- [x] Capture required workspace nav states and breadcrumbs in a shared checklist for later verification.
- [x] Establish a baseline by running existing admin LiveView tests (`mix test test/oli_web/live/admin`) and note current failures, if any.

**Definition of Done**

- Route inventory, nav/breadcrumb matrix, and token alignment notes reviewed with Design & Product.
- Existing automated tests for admin areas are green, establishing the baseline regression suite.
- Open questions around navigation scope and feature flag resolved or captured for follow-up.

Gate: Phase 1 cannot start until the baseline artifacts and decisions are approved.

---

## Phase 1: Workspace Shell Integration for Admin LiveViews

**Goal** Move admin LiveViews onto the shared workspace shell with an `Admin` nav entry that routes to `/admin` and stays active.

**Tasks**

- [x] Implement the `:admin_workspace` live_session wiring (root layout + workspace layout) per `fdd.md`.
- [x] Extend `OliWeb.Components.Delivery.Layouts.workspace_sidebar_nav/1` to render the `Admin` entry for admin-role users and include dark-mode iconography parity.
- [x] Update `OliWeb.LiveSessionPlugs.AssignActiveMenu` and `SetSidebar` to tag `active_workspace: :admin` for admin/community modules.
- [x] Add LiveView tests that cover nav visibility, role-gating, and active state persistence across `/admin/**` routes (e.g., new suite under `test/oli_web/live/admin/nav_live_test.exs`).
- [x] Run `mix test test/oli_web/live/admin/nav_live_test.exs` and the existing admin LiveView suite.

**Definition of Done**

- All admin LiveViews render through the shared workspace shell with the `Admin` nav entry visible only to authorized users.
- Active nav state persists across LiveView navigations and websocket reconnects; tests cover role gating and active state.
- No regressions in existing admin LiveView tests.

Gate: Phase 2 and Phase 3 work may begin only after the shared shell and nav wiring are merged to main.

---

## Phase 2: Breadcrumb & Theming Consistency (LiveViews)

**Goal** Align breadcrumbs and theming across admin LiveViews with shared components and gettext coverage.

**Tasks**

- [x] Replace legacy breadcrumb markup with the shared breadcrumb component; ensure breadcrumbs appear on every admin LiveView.
- [x] Inject fallback `Admin` crumb where previously absent, reusing gettext strings or adding translations as needed.
- [x] Verify light/dark theme parity by adopting shared button, table, and form components in LiveViews; remove redundant inline styles.
- [x] Add LiveView tests validating breadcrumb structure and dark-mode classes (e.g., `test/oli_web/live/admin/breadcrumb_live_test.exs`).
- [x] Run `mix test test/oli_web/live/admin/breadcrumb_live_test.exs`.

**Definition of Done**

- Every admin LiveView renders shared breadcrumbs and respects dark-mode toggles; screenshots in light/dark mode signed off by Design.
- Breadcrumb translations are localized and pass i18n checks.
- New tests pass and protect breadcrumb/theming regressions.

Parallel: Phase 2 can run concurrently with Phase 3 once Phase 1 completes, provided coordination on shared templates.

---

## Phase 3: Legacy Controller & Community Route Integration

**Goal** Wrap controller-rendered pages and `/authoring/communities/**` flows in the shared workspace shell while preserving community sub-navigation.

- [x] Adapt ingest/report controllers (invite, brands, manage activities, course ingestion, etc.) to supply required assigns for the shared layout (breadcrumbs, ctx, active_workspace) and restore the legacy course ingestion endpoints referenced by `Routes.ingest_path/3`.
- [x] Ensure community LiveViews retain their sub-navigation while inheriting the `Admin` active nav state; adjust templates as needed.
- [x] Add controller and integration tests covering the shared layout assigns and navigation highlighting (e.g., `test/oli_web/controllers/admin_layout_controller_test.exs`).
- [x] Validate LiveDashboard or other embedded tools within the workspace shell, ensuring the `Admin` menu renders and remains active; implement documented fallback only if the shell cannot wrap them while preserving the menu.
- [x] Run `mix test test/oli_web/controllers/admin_layout_controller_test.exs`.

**Definition of Done**

- Admin controllers and community routes render within the shared workspace layout without missing assigns or crashes; legacy workspace templates are removed once unused.
- Admin nav remains active across community routes and LiveDashboard with automated tests proving coverage.
- Any non-conforming routes have approved remediation or documented rationale.

Parallel: Coordinate with Phase 2 to avoid conflicting template changes; otherwise executable in parallel after Phase 1.

---

## Phase 4: CSS Consolidation, Telemetry, and Performance Validation

**Goal** Remove legacy styling, wire telemetry, and ensure non-functional guardrails are met.

**Tasks**

- [x] Delete or refactor legacy admin CSS files; replace usage with shared design system classes.
- [x] Capture before/after asset bundle sizes via `mix assets.deploy` (dry run) to prove payload growth ≤ 50 KB gzipped.
- [x] Run `mix test test/oli_web/live/admin` and `mix test test/oli_web/controllers/admin_layout_controller_test.exs` to confirm regressions absent post-cleanup.

**Definition of Done**

- Legacy admin CSS removed without UI regressions; asset diff documented and within budget.

Dependencies: Requires Phases 2 and 3 merged to avoid dead code; telemetry work can begin while CSS cleanup is in review.

---

## Phase 5: Authoring Workspace Route Migration

**Goal** Retire legacy `/authoring/**` product/project routes by moving functionality under `/workspaces/course_author/**`.

**Plan**

1. **Products & Payments**
   - [ ] Add workspace routes for product list/detail/payments/certificate settings under `/workspaces/course_author/:project_id/products/**` (tests partially updated; LiveViews still need full routing + redirects).
   - [ ] Update LiveViews (`overview`, `products`, `remix`, etc.), components, and tests to rely on the new paths and breadcrumbs.
   - [ ] Bring admin discount flows onto the shared workspace navigation while preserving role gating.
2. **Project Management Actions**
   - [ ] Replace controller endpoints (`create`, `clone`, `enable_triggers`, CSV exports) with workspace-compatible routes or LiveView events.
   - [ ] Update workspace UI (modals, buttons) and tests to use the new endpoints.
3. **Cleanup**
   - [ ] Remove unused `/authoring/**` routes, controllers, and tests once all callers use workspace equivalents.
   - [ ] Re-run targeted suites (products, payments, projects, imports) to confirm parity.

**Verification Checklist Before Handoff**

- All phases include automated test additions with explicit commands.
- Non-functional requirements traced back to guardrails with validation steps.
- Clarifications either resolved or documented for the implementer to confirm.
---

## Current Status (2025-02-14)

- Updated multiple product and objectives LiveView tests plus supporting helpers to target `/workspaces/course_author/**` routes; removed the legacy `Products.DetailsView` module and its scoped-features suite.
- Certificates and granted-certificate controllers now point to workspace URLs, but workspace remix flows still fail because `project_slug` assignment in `OliWeb.Delivery.RemixSection` is incomplete (nil slug during redirect) and migrating tests remain red.
- Next up: finish the `RemixSection` migration (derive `project_slug` for every mount path, replace `Routes.product_remix_path` callers, add helper coverage), audit remaining workspace migrations (publish, insights, etc.), and rerun `mix test` once the targeted suites are green.

