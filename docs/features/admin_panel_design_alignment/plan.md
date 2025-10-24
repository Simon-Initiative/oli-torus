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

- [ ] Adapt ingest/report controllers (invite, brands, manage activities, course ingestion, etc.) to supply required assigns for the shared layout (breadcrumbs, ctx, active_workspace) and restore the legacy course ingestion endpoints referenced by `Routes.ingest_path/3`.
- [ ] Ensure community LiveViews retain their sub-navigation while inheriting the `Admin` active nav state; adjust templates as needed.
- [ ] Add controller and integration tests covering the shared layout assigns and navigation highlighting (e.g., `test/oli_web/controllers/admin_layout_controller_test.exs`).
- [ ] Validate LiveDashboard or other embedded tools within the workspace shell, ensuring the `Admin` menu renders and remains active; implement documented fallback only if the shell cannot wrap them while preserving the menu.
- [ ] Run `mix test test/oli_web/controllers/admin_layout_controller_test.exs`.

**Definition of Done**

- Admin controllers and community routes render within the shared workspace layout without missing assigns or crashes; legacy workspace templates are removed once unused.
- Admin nav remains active across community routes and LiveDashboard with automated tests proving coverage.
- Any non-conforming routes have approved remediation or documented rationale.

Parallel: Coordinate with Phase 2 to avoid conflicting template changes; otherwise executable in parallel after Phase 1.

---

## Phase 4: CSS Consolidation, Telemetry, and Performance Validation

**Goal** Remove legacy styling, wire telemetry, and ensure non-functional guardrails are met.

**Tasks**

- [ ] Delete or refactor legacy admin CSS files; replace usage with shared design system classes.
- [ ] Capture before/after asset bundle sizes via `mix assets.deploy` (dry run) to prove payload growth ≤ 50 KB gzipped.
- [ ] Run `mix test test/oli_web/live/admin` and `mix test test/oli_web/controllers/admin_layout_controller_test.exs` to confirm regressions absent post-cleanup.

**Definition of Done**

- Legacy admin CSS removed without UI regressions; asset diff documented and within budget.

Dependencies: Requires Phases 2 and 3 merged to avoid dead code; telemetry work can begin while CSS cleanup is in review.

---

## Phase 5: QA, Accessibility, and Rollout Readiness

**Goal** Validate end-to-end experience, finalize documentation, and prepare for deployment.

**Tasks**

- [ ] Execute cross-browser and dark-mode manual QA across key admin flows, referencing the checklist from Phase 0.
- [ ] Perform keyboard-only and screen reader (VoiceOver/NVDA) checks; ensure focus outlines and ARIA attributes mirror the authoring workspace.
- [ ] Confirm multi-tenant scoping by spot-checking admin access in multiple institutions and ensuring non-admin roles cannot see the `Admin` nav.
- [ ] Update release notes, admin support docs, and ensure `prd.md`/`fdd.md` reflect final decisions (feature flag outcome, telemetry dashboards).
- [ ] Run full automated suite touching admin areas: `mix test test/oli_web/live/admin`, `mix test test/oli_web/controllers/admin_layout_controller_test.exs`, and smoke the asset build (`mix assets.deploy --quiet`).
- [ ] Capture staging sign-off from Product, Design, and Support; log verification in rollout checklist.

**Definition of Done**

- Accessibility, security, and tenancy checks signed off; no outstanding high-severity defects.
- Documentation, screenshots, and telemetry dashboards ready for launch.
- Staging sign-off complete; rollback steps documented if needed.

Gate: Production deploy proceeds only after Phase 5 checklist is complete.

---

**Parallelization & Dependency Notes**

- Phase 0 is mandatory upfront and unlocks all subsequent phases.
- Phase 1 establishes the shared shell; Phases 2 and 3 may progress in parallel afterwards with tight coordination on shared templates.
- Telemetry wiring from Phase 4 can start once nav routing is stable (post-Phase 1) but cannot close until CSS consolidation completes (post-Phase 2/3).
- QA in Phase 5 depends on completion of all prior phases; however, accessibility audits can begin opportunistically during Phase 2/3 implementations.

**Verification Checklist Before Handoff**

- All phases include automated test additions with explicit commands.
- Non-functional requirements traced back to guardrails with validation steps.
- Clarifications either resolved or documented for the implementer to confirm.
