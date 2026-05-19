# Iframe Links — PRD

## 1. Overview
Feature Name: Iframe Links

Summary: Enable adaptive-page authors to configure `janus-capi-iframe` sources using a checkbox-based source-type selector in the Custom panel (`External URL` vs `Page Link`), where page links are stored as stable `resource_id` references. Internal iframe page links are rewritten for authoring preview, instructor preview, and section delivery contexts so embedded content resolves correctly across preview and live runtime.

Links: `docs/epics/adaptive_page_improvements/iframe_links/informal.md`, `docs/epics/adaptive_page_improvements/dynamic_links/prd.md`, `docs/epics/adaptive_page_improvements/plan.md`, ticket `MER-5212`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Adaptive text links support internal link semantics, but iframe `src` in adaptive activities is currently treated as a plain string.
  - `/course/link/<slug>` rewriting logic is anchor-specific and does not apply to iframe source fields.
  - Authors must hardcode section-specific or environment-specific URLs for embedded course content, which is fragile.
- Affected users/roles:
  - Authors creating adaptive pages with embedded iframe content.
  - Students consuming adaptive pages that embed other course pages.
  - Instructors reviewing adaptive content in section preview/delivery contexts.
- Why now:
  - Epic lane sequencing defines `MER-5212` immediately after `MER-5211` (`dynamic_links`) so iframe source links can reuse the same resource-id-driven link model.

## 3. Goals & Non-Goals
- Goals:
  - Provide a checkbox-based source-type toggle in iframe Custom configuration to switch between URL entry and page-link dropdown selection.
  - Allow authors to set iframe source as an internal course page reference from adaptive authoring.
  - Persist iframe internal references using `resource_id` as source of truth.
  - Resolve iframe internal references to section runtime lesson URLs during delivery.
  - Provide clear authoring validation and clear student-facing fallback behavior for unresolved references.
  - Preserve internal iframe link integrity through import/export rewiring.
- Non-Goals:
  - Supporting links to adaptive screens/activities within a page (screen-deep linking).
  - Redesigning the page-level adaptive chrome iframe flow (`adaptive_content_iframe`).
  - Introducing feature flags for this feature.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Course author in adaptive authoring context.
  - Student in section lesson delivery context.
  - Instructor in section preview/review context.
- Use Cases:
  - Author configures a `janus-capi-iframe` part to point to another page in the same project via a structured internal reference.
  - Author previews an adaptive page with internal iframe source and sees iframe `src` rewritten from `/course/link/<slug>` to the authoring preview route.
  - Student loads an adaptive page and sees embedded iframe content resolve correctly to the current section lesson route.
  - Author receives validation feedback when an internal iframe target is invalid, deleted, or outside allowed scope.

## 5. UX / UI Requirements
- Key Screens/States:
  - Adaptive iframe configuration UI with checkbox-based source type selection in Custom section (`Page Link` vs `External URL`), following popup editor interaction style.
  - External URL state: selecting `External URL` displays the `Source` text input.
  - Page Link state: selecting `Page Link` displays a project-page dropdown (picker-only; no direct slug entry).
  - Authoring/preview runtime state: iframe source rewrite resolves internal `/course/link/<slug>` sources to preview-aware paths before iframe load.
  - Internal page picker/search state with loading, empty, and error feedback (picker-only selection; no direct slug entry).
  - Authoring validation state for invalid/deleted/internal target mismatch.
  - Delivery fallback state for unresolved iframe source.
- Navigation & Entry Points:
  - Entry from adaptive iframe part configuration panel (`janus-capi-iframe`).
  - Delivery rendering path for adaptive activity parts.
- Accessibility:
  - Source-type controls and page picker must be keyboard operable with visible focus and screen-reader labels.
  - Validation and fallback messages must be announced to assistive technologies.
  - Iframe fallback must not trap keyboard focus.
- Internationalization:
  - New authoring and delivery strings are localizable and translation-ready.
  - No locale-specific URL or resolution logic.
- Screenshots/Mocks:
  - None

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Performance & Scale: Instrument iframe internal-link resolution latency and failure rate; AppSignal alert when p95 resolution latency exceeds 100 ms for 15 minutes or resolution failure rate exceeds 1% over 15 minutes.
- Reliability: If an internal iframe source cannot be resolved, delivery must fail safely for the iframe element only and continue rendering the rest of the adaptive page.
- Security & Privacy: Internal iframe source resolution must enforce project/section/tenant authorization and must not expose cross-tenant page metadata.
- Compliance: Authoring and delivery states introduced by this feature must meet WCAG 2.1 AA expectations.
- Observability: Emit telemetry for internal iframe source create/update/remove, delivery resolution success/failure, and fallback rendering.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - No new tables or schema migrations.
  - Adaptive activity content JSON expands to support structured iframe source metadata for internal links (resource-id based).
- Context Boundaries:
  - Adaptive authoring serialization/validation (`activity_editor` pipeline).
  - Adaptive delivery rewrite path (`rendering/activity/html`).
  - Interop import/export rewiring path.
- APIs / Contracts:
  - Authoring UI contract: source-type checkboxes control which source editor is visible (`External URL` text input or `Page Link` dropdown).
  - Authoring contract: internal iframe source stores `resource_id`-based reference selected through the picker; revision slug is not persisted as source of truth.
  - Runtime rewrite contract for internal iframe source:
    - authoring preview: `/authoring/project/:project_slug/preview/:page_slug`
    - instructor preview: `/sections/:section_slug/preview/page/:page_slug`
    - delivery: `/sections/:section_slug/lesson/:page_revision_slug`
  - Fallback contract: unresolved internal iframe source renders explicit fallback UI/state.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Author | Configure internal iframe source to in-project pages; save/remove internal source | Scoped to authorized project resources |
| Instructor | Preview resulting iframe behavior in section preview | No authoring mutation rights |
| Student | View resolved iframe content in delivery | No link/source editing rights |
| Admin | Same as author in authorized contexts | Tenant boundaries still enforced |

## 10. Integrations & Platform Considerations
- LTI 1.3: Section-context route resolution must remain correct for LTI-launched learners.
- GenAI (if applicable): Not applicable.
- External services: No new external integration; existing iframe external URL behavior remains supported.
- Caching/Perf: Reuse existing resource summary/depot lookups with per-render memoization where needed to avoid repeated lookups per iframe.
- Multi-tenancy: Internal source options, validation, rewiring, and runtime resolution must remain scoped to the current project/section and institution boundaries.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - Internal iframe source save success rate in authoring.
  - Internal iframe source delivery resolution success rate.
  - Unresolved internal iframe fallback rate.
- Events:
  - `adaptive_iframe_link_created`
  - `adaptive_iframe_link_updated`
  - `adaptive_iframe_link_removed`
  - `adaptive_iframe_link_resolved`
  - `adaptive_iframe_link_resolution_failed`
  - `adaptive_iframe_link_fallback_rendered`

## 13. Risks & Mitigations
- Divergent link models between text links and iframe sources create maintenance risk -> reuse dynamic-links resource-id model and normalization approach.
- Legacy adaptive content with string-only iframe `src` may mix internal/external patterns -> keep external URL behavior unchanged and normalize only internal-source patterns.
- Invalid/deleted targets may produce broken embedded areas for students -> enforce authoring validation and delivery fallback.
- Route resolution regressions could generate wrong section URLs -> add regression tests for section-scoped rewrite behavior and telemetry alerts.

## 14. Open Questions & Assumptions
- Assumptions:
  - This feature supports internal links to pages only, not screen-level targets.
  - `MER-5211` dynamic-links foundation is available and can be extended for iframe source normalization and rewrite.
  - Existing adaptive delivery route contract remains `/sections/:section_slug/lesson/:page_revision_slug`.
  - Internal iframe source selection is picker-only; free-text slug entry is out of scope.
- Open Questions:
  - What exact fallback visual pattern should be used in delivery for unresolved iframe internal sources (inline message vs replacement component)?

## 15. Timeline & Milestones (Draft)
- Milestone 1: Finalize iframe internal-source JSON contract and authoring UX requirements.
- Milestone 2: Implement authoring validation/normalization for internal iframe source references.
- Milestone 3: Implement import/export rewiring and delivery-time iframe source rewrite.
- Milestone 4: Add fallback behavior, telemetry, and regression coverage.

## 16. QA Plan
- Automated:
  - Unit/integration tests for authoring internal iframe source validation and normalization.
  - Delivery rendering tests for iframe source rewrite and unresolved fallback behavior.
  - Frontend resolver tests for preview-route rewriting of iframe internal links.
  - Import/export rewiring tests for internal iframe resource-id remapping.
  - Authorization tests for project/section/tenant boundaries.
  - Telemetry emission tests for create/update/resolve/failure/fallback paths.
- Performance Validation:
  - Verify telemetry/AppSignal metrics and alert thresholds for iframe-link resolution latency and failure rate.
- Manual:
  - Validate authoring UX for checkbox source-type selection, state switching between URL input and page dropdown, page picker states, and validation messaging.
  - Validate student delivery fallback clarity and behavior when target is invalid/deleted.
  - Validate accessibility for keyboard-only navigation and screen-reader announcements in new authoring/delivery states.
  - Focus areas for manual testing based on risky or hard-to-automate behavior: mixed legacy string `src` values, malformed internal references, and cross-section preview parity.
- Oli.Scenarios Recommendation:
  - Status: Required
  - Rationale: This feature changes authoring-to-delivery non-UI workflow behavior (internal reference normalization, delivery resolution, and fallback) that should be protected by high-level scenario coverage.
  - Existing Coverage Signal: Existing YAML scenarios already cover project creation/publishing/section workflows in `test/scenarios/features/*.scenario.yaml`, `test/scenarios/delivery/**/*.scenario.yaml`, and `test/scenarios/sections/*.scenario.yaml`, but no adaptive iframe-link specific scenarios were found.
  - Infrastructure Support Status: Unsupported
  - Scenario Infrastructure Expansion Required: Yes
  - Required Scope (AC/workflows): End-to-end workflow from authoring adaptive iframe internal source setup through publish/section delivery resolution and unresolved-target fallback behavior.
  - Planned Artifacts: `test/scenarios/delivery/adaptive_iframe_internal_link_resolution.scenario.yaml`; runner coverage through `test/scenarios/scenario_runner_test.exs`.
  - Validation Commands: `mix test test/scenarios/validation/schema_validation_test.exs`; `mix test test/scenarios/scenario_runner_test.exs`.
  - Planning Handoff: spec_plan must schedule $spec_scenario_expand before $spec_scenario
- LiveView Testing Recommendation:
  - Status: Not applicable
  - Rationale: The expected implementation surface is adaptive React authoring/delivery rendering and backend rewrite/validation paths, not a material LiveView UI change.
  - Affected UI Surface: None
  - Required Scope (events/states): N/A
  - Planned Artifacts: N/A
  - Validation Commands: N/A

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] If feature flags are required, rollout/rollback posture is documented; otherwise Section 11 contains only the required no-feature-flag statement

## Decision Log
### 2026-03-09 - Add Authoring Preview Iframe Source Rewrite Requirement
- Change: Updated summary, use cases, UX states, runtime contracts, and QA coverage to explicitly require `/course/link/<slug>` rewrite for authoring preview and instructor preview contexts in addition to section delivery.
- Reason: Implementation added preview-aware iframe source rewriting to prevent direct `/course/link/*` route requests during preview.
- Evidence: `assets/src/components/parts/janus-capi-iframe/sourceResolver.ts`; `assets/src/components/parts/janus-capi-iframe/ExternalActivity.tsx`; `assets/src/components/parts/janus-capi-iframe/CapiIframeAuthor.tsx`; `assets/test/advanced_authoring/right_menu/component/iframe_source_resolver_test.ts`.
- Impact: Clarifies AC-004 scope to include preview route parity, and adds explicit regression expectations for authoring preview behavior.
