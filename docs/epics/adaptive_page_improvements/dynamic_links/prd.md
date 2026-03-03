# Dynamic Links — PRD

## 1. Overview
Feature Name: Dynamic Links

Summary: Enable adaptive-page authors to create internal text links that point to other course pages using stable `resource_id` references, not slugs. At delivery time, the system resolves those references to section-correct lesson URLs so links remain valid across section creation, export/import, and content lifecycle changes.

Links: `docs/epics/adaptive_page_improvements/dynamic_links/informal.md`, `docs/epics/adaptive_page_improvements/overview.md`, `docs/epics/adaptive_page_improvements/plan.md`, ticket `MER-5211`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Basic pages support internal linking semantics, but adaptive pages do not provide equivalent dynamic internal links.
  - Adaptive authors must use hardcoded URLs or avoid linking, which is brittle across environments and section remaps.
  - Import/export reliability is at risk when links depend on revision slugs instead of durable `resource_id` references.
- Affected users/roles:
  - Authors building adaptive pages with connected navigation flows.
  - Students consuming adaptive pages in section delivery.
- Why now:
  - Epic lane sequencing defines `MER-5211` as the foundation for adaptive dynamic linking and as a prerequisite for `MER-5212` iframe dynamic-link support.

## 3. Goals & Non-Goals
- Goals:
  - Provide adaptive authoring UI to create in-text internal links to project resources.
  - Persist internal adaptive links in a `resource_id`-based structure.
  - Resolve internal links to correct section lesson URLs during delivery rendering.
  - Preserve link integrity through import/export by rewiring internal references.
  - Provide clear behavior for invalid/broken links and link-target deletion attempts.
- Non-Goals:
  - Supporting iframe dynamic link sources (covered by `MER-5212`).
  - Introducing slug-based internal link persistence for adaptive links.
  - Redesigning basic-page link behavior in this feature.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Course author in adaptive authoring context.
  - Student in section lesson delivery context.
- Use Cases:
  - Author selects text in an adaptive screen and links it to another page in the same project using a picker.
  - Student clicks an internal adaptive link and lands on the correct section lesson in a new tab.
  - Course content is exported and imported into another project, and adaptive internal links remain valid after ID rewiring.

## 5. UX / UI Requirements
- Key Screens/States:
  - Adaptive text editing UI with add/edit internal link flow for text nodes.
  - Link target picker listing eligible in-project resources with clear selected target state.
  - Author warning modal/state when deleting a target with inbound adaptive dynamic links.
  - Student-facing graceful error state for unresolved internal links with return/report affordance.
- Navigation & Entry Points:
  - Entry from adaptive author text editing controls for hyperlink insertion and edit.
  - Student navigation from rendered adaptive content links.
- Accessibility:
  - Link picker and warning states must be keyboard operable with visible focus and screen-reader labels.
  - Link text remains semantic anchor content for assistive technology.
  - Broken-link messaging and actions are announced to assistive technology.
- Internationalization:
  - New authoring and delivery strings are localizable and translation-ready.
  - No locale-dependent logic in link resolution.
- Screenshots/Mocks:
  - None

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Performance & Scale: Track adaptive-link resolution latency and error rate via telemetry/AppSignal; alert when section delivery adaptive-link resolution failure rate exceeds agreed operational threshold.
- Reliability: Link resolution and rewrite paths must fail safely (no page crash), provide fallback UX for unresolved links, and keep rendering of other content unaffected.
- Security & Privacy: Internal-link resolution must enforce section and project authorization boundaries and must not expose cross-tenant resource metadata.
- Compliance: Accessibility behavior for authoring controls and delivery link/error states must meet WCAG 2.1 AA expectations.
- Observability: Emit telemetry for author link-create/update/remove actions, delivery resolution success/failure, broken-link clicks, and deletion-block warnings.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - No new DB tables required.
  - Existing adaptive content JSON payloads will include a structured internal-link representation containing `resource_id` (for example via `idref`), and must not rely on revision slug persistence.
- Context Boundaries:
  - Adaptive authoring UI and serialization layer.
  - Interop ingest/import rewiring pipeline.
  - Delivery-side adaptive content fetch/render rewrite path (including bulk activity fetch path).
- APIs / Contracts:
  - Authoring contract: internal adaptive link objects must carry `resource_id` and external links remain unchanged.
  - Import contract: adaptive internal link references are remapped to new resource IDs during import.
  - Delivery contract: adaptive internal links are rewritten to `/sections/:section_slug/lesson/:page_revision_slug` URLs at render time.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Author | Create/edit/remove adaptive internal links; view deletion warnings | Scoped to project resources they can author |
| Instructor | No authoring actions; may preview delivery behavior in instructor preview contexts | Existing preview permissions apply |
| Student | Click resolved internal links in delivery | No authoring/edit capability |
| Admin | Same as author in authorized projects | Institution and project scoping enforced |

## 10. Integrations & Platform Considerations
- LTI 1.3: Delivery link behavior must remain section-context correct under existing LTI launch and enrollment authorization.
- GenAI (if applicable): Not applicable.
- External services: None.
- Caching/Perf: Reuse existing resolver/depot and adaptive delivery fetch patterns; avoid introducing per-link expensive lookups in render loops.
- Multi-tenancy: Link picker, import rewiring, and delivery resolution must only operate within authorized project/section boundaries.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - Adaptive internal-link creation success rate in authoring.
  - Adaptive internal-link delivery resolution success rate.
  - Broken-link click rate in delivery.
  - Deletion-warning intervention rate for linked targets.
- Events:
  - `adaptive_dynamic_link_created`
  - `adaptive_dynamic_link_updated`
  - `adaptive_dynamic_link_removed`
  - `adaptive_dynamic_link_resolved`
  - `adaptive_dynamic_link_resolution_failed`
  - `adaptive_dynamic_link_broken_clicked`
  - `adaptive_dynamic_link_delete_blocked`

## 13. Risks & Mitigations
- Divergent link structures between basic and adaptive content increase maintenance risk -> define one canonical adaptive internal-link representation with `resource_id` and document serializer/rewriter responsibilities.
- Import rewiring misses adaptive nested link nodes -> make rewiring traversal reusable/parameterizable for adaptive content structures and add regression coverage.
- Delivery rewrite regressions create dead links -> add resolution-failure telemetry and user-safe fallback messaging.
- Author confusion when targets are deleted -> show clear inbound-link warning with source context before deletion confirmation.

## 14. Open Questions & Assumptions
- Assumptions:
  - Adaptive internal links in this feature target pages/resources resolvable to lesson routes, not screen-deep links.
  - Existing adaptive content serialization can be extended to carry `resource_id`-based internal link fields.
  - Existing section delivery routes for lessons remain `/sections/:section_slug/lesson/:page_revision_slug`.
- Open Questions:
  - Should unresolved-link reporting open an existing support/report flow or use a dedicated adaptive-link report action?
  - Should authoring picker include only page resources, or all linkable resource types that can resolve to lesson destinations?

## 15. Timeline & Milestones (Draft)
- Milestone 1: Define adaptive internal-link data contract and authoring picker/edit UX.
- Milestone 2: Implement import rewiring support for adaptive internal links using `resource_id` remapping.
- Milestone 3: Implement delivery-time adaptive internal-link URL resolution and broken-link fallback UX.
- Milestone 4: Add deletion-warning protections, telemetry, and regression hardening.

## 16. QA Plan
- Automated:
  - Unit tests for adaptive link serialization and validation (`resource_id`-only internal link persistence).
  - Ingest/import tests validating adaptive internal link rewiring to new resource IDs.
  - Delivery rendering tests validating internal link rewrite to section lesson URLs.
  - Authorization tests for link picker scoping and delivery resolution boundaries.
  - Telemetry event coverage tests for create/update/resolve/failure paths.
- Performance Validation:
  - Verify telemetry and AppSignal dashboards/alerts for adaptive-link resolution latency and failure-rate thresholds in staging/production-like environments.
- Manual:
  - Authoring flow validation for create/edit/remove internal links and keyboard accessibility in link picker.
  - Delivery validation for correct new-tab navigation and request-path continuity where applicable.
  - Broken-link fallback validation: message clarity, return behavior, and issue-report action.
  - Deletion-warning validation for resources with inbound adaptive links, including source-link visibility.
- Oli.Scenarios Recommendation:
  - Status: Suggested
  - Rationale: This feature touches delivery and import/link-rewrite behaviors that map well to YAML scenario coverage, but it also includes adaptive authoring UI interactions that remain better covered by targeted UI/integration tests.
  - Existing Coverage Signal: Existing `Oli.Scenarios` YAML coverage is present in delivery/section and content-update areas (`test/scenarios/delivery/**`, `test/scenarios/sections/**`), indicating scenario tests are a good fit for end-to-end adaptive-link rewrite and navigation flows.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] If feature flags are required, rollout/rollback posture is documented; otherwise Section 11 contains only the required no-feature-flag statement
