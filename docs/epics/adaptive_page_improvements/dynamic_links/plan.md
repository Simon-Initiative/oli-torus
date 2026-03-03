# Dynamic Links — Delivery Plan

Scope and guardrails reference:
- PRD: `docs/epics/adaptive_page_improvements/dynamic_links/prd.md`
- FDD: `docs/epics/adaptive_page_improvements/dynamic_links/fdd.md`

## Scope
Deliver MER-5211 dynamic links for adaptive pages: authoring-side internal link creation/editing with `resource_id`-based persistence, import/export rewiring, delivery-time section URL resolution, unresolved-link fallback UX, inbound delete warnings, and telemetry coverage. Scope excludes iframe dynamic-link sources (MER-5212).

## Non-Functional Guardrails
- Security/authz: link picker and resolver must enforce project/section/tenant boundaries (FR-009).
- Reliability: unresolved internal links must fail safely without breaking page rendering (FR-007).
- Performance posture: instrument and monitor resolution latency/failure via telemetry/AppSignal; no dedicated load/benchmark tasks.
- Data safety: no DB schema migration; JSON contract changes remain backward-compatible for existing adaptive content.
- Observability: emit and validate all telemetry events listed in PRD/FDD (FR-010).
- Accessibility: authoring picker and delivery fallback states must remain keyboard/screen-reader operable.

## Clarifications & Default Assumptions
- Internal adaptive dynamic links in this slice target lesson-addressable page resources only.
- Existing adaptive text node schema can be extended without migration by adding internal-link metadata fields.
- Route contract remains `/sections/:section_slug/lesson/:page_revision_slug`.
- Unresolved-link report action initially reuses existing issue-report flow if available; otherwise route to existing support affordance.
- No feature flag is introduced for this feature (per PRD Section 11).

## FR/AC to Phase Traceability
| Requirement | Planned phase coverage | Verification stage |
|---|---|---|
| FR-001 / AC-001 | Phase 1, Phase 4 | Authoring UI and integration tests |
| FR-002 / AC-002 | Phase 1 | Serialization/contract unit tests |
| FR-003 / AC-003 | Phase 1, Phase 3 | Contract + delivery rewrite tests |
| FR-004 / AC-004 | Phase 2 | Interop rewiring tests |
| FR-005 / AC-005 | Phase 3 | Delivery URL rewrite tests |
| FR-006 / AC-006 | Phase 3 | New-tab behavior tests |
| FR-007 / AC-007 | Phase 3, Phase 4 | Fallback behavior tests |
| FR-008 / AC-008 | Phase 4 | Delete warning tests |
| FR-009 / AC-009 | Phase 1, Phase 3, Phase 4 | Authz boundary tests |
| FR-010 / AC-010 | Phase 5 | Telemetry instrumentation tests/checks |

## Phase 1: Canonical Link Contract and Authoring Serialization
- Goal: Define and enforce adaptive internal/external link JSON contract so downstream rewiring and delivery logic can rely on stable data.
- Tasks:
  - [x] Finalize canonical adaptive internal link node shape (`idref`/`resource_id`) and external link shape (`href`).
  - [x] Implement serializer/deserializer updates in adaptive authoring save path.
  - [x] Add validation preventing slug-as-source persistence for internal links.
  - [x] Add authorization filtering contract for eligible link picker resources in authoring APIs.
  - [x] Document contract examples in feature docs/comments where code path is non-obvious.
- Testing Tasks:
  - [x] Add unit tests for internal/external link serialization and validation.
  - [x] Add negative tests for invalid/mixed link payloads and unauthorized targets.
  - [x] Run targeted tests.
  - Command(s): `mix test test/oli_web/controllers/api/activity_controller_test.exs test/oli/rendering/activity/html_test.exs`
- Definition of Done:
  - Internal links persist only `resource_id`-based references.
  - External links remain unchanged through save/retrieve flows.
  - Authorization boundary checks pass for link target listing.
- Gate:
  - Phase 1 tests pass and contract is stable for interop and delivery consumers.
- Dependencies:
  - None.
- Parallelizable Work:
  - API payload validation tests and serializer implementation can proceed in parallel once the contract shape is agreed.

## Phase 2: Import/Export Rewiring for Adaptive Links
- Goal: Ensure adaptive internal links survive content export/import through deterministic resource-id rewiring.
- Tasks:
  - [x] Extend export rewiring to preserve/normalize adaptive internal link references into portable idref form.
  - [x] Extend ingest/import rewiring traversal to map adaptive link references to destination resource IDs.
  - [x] Add idempotency protections so rewiring is deterministic for repeated runs.
  - [x] Add warning/telemetry hooks for remap misses.
- Testing Tasks:
  - [x] Add interop tests that import adaptive content with internal links and verify remapped IDs.
  - [x] Add regression tests for nested link nodes and mixed internal/external links.
  - [x] Run targeted tests.
  - Command(s): `mix test test/oli/interop/rewire_links_test.exs test/oli/interop/ingest/processor/rewiring_test.exs`
- Definition of Done:
  - Imported adaptive internal links resolve to destination resource IDs.
  - Export/import rewiring is deterministic and does not alter external links.
- Gate:
  - Interop tests pass for happy-path and remap-miss cases.
- Dependencies:
  - Phase 1 canonical link contract.
- Parallelizable Work:
  - Export and ingest rewiring implementations can run in parallel and converge in integration tests.

## Phase 3: Delivery Resolution, URL Rewriting, and Safe Fallback
- Goal: Resolve adaptive internal links in section context at render time and deliver safe student navigation behavior.
- Tasks:
  - [x] Implement delivery resolver path for adaptive internal links using section/project scoped lookup.
  - [x] Rewrite resolved links to `/sections/:section_slug/lesson/:page_revision_slug`.
  - [x] Enforce `target="_blank"` behavior for internal adaptive links in delivery.
  - [x] Implement unresolved-link fallback UI/behavior without breaking full page render.
  - [x] Add per-request memoization to avoid repeated resource lookup overhead.
- Testing Tasks:
  - [x] Add rendering tests for internal link rewrite, new-tab behavior, and external link pass-through.
  - [x] Add unresolved-link fallback tests and section-boundary authorization tests.
  - [x] Run targeted tests.
  - Command(s): `mix test test/oli/rendering/content/html_test.exs test/oli_web/controllers/page_delivery_controller_test.exs`
- Definition of Done:
  - Internal links resolve and rewrite correctly in section delivery.
  - Unresolved links display fallback behavior and do not crash rendering.
  - External links remain unchanged.
- Gate:
  - Delivery rewrite/fallback/security tests pass in section-context scenarios.
- Dependencies:
  - Phase 1 contract; Phase 2 rewiring behavior for imported content parity.
- Parallelizable Work:
  - Fallback UX and resolver memoization can be developed in parallel once base rewrite path is in place.

## Phase 4: Authoring UX Completion and Deletion Guardrails
- Goal: Complete author-facing workflows for link picker/editing and protect authors from deleting linked targets without warning.
- Tasks:
  - [x] Implement adaptive text link picker UI for create/edit/remove internal links.
  - [ ] Ensure keyboard navigation, focus handling, and i18n string wiring for picker/fallback/deletion warnings.
  - [x] Ensure page-link picker renders a page selector in all states (loading/error/empty/success) and populates from in-course pages when available.
  - [x] Wire adaptive part authoring context project slug into text-flow link picker page lookup.
  - [x] In author preview, intercept `/course/link/:slug` clicks in adaptive text flow and show an explanatory inline notice instead of attempting navigation.
  - [x] Implement inbound adaptive-link detection for target-resource deletion attempts.
  - [x] Show warning modal/state with source-context before deletion confirmation.
- Testing Tasks:
  - [ ] Add UI/integration tests for picker flows (create/edit/remove).
  - [ ] Add UI test for author-preview internal-link interception notice behavior.
  - [x] Add tests for deletion warning trigger and source-context display.
  - [ ] Add accessibility assertions for keyboard and screen-reader labels in new UI states.
  - Command(s): `mix test test/oli_web/live/workspaces/course_author/*.exs`
- Definition of Done:
  - Authors can create/edit/remove internal links through supported UI flow.
  - Deletion warning appears when inbound adaptive links exist and includes source context.
  - Accessibility checks pass for new states.
- Gate:
  - Authoring and deletion-guard tests pass and UX strings are localizable.
- Dependencies:
  - Phase 1 contract; Phase 3 delivery behavior for end-to-end author confidence.
- Parallelizable Work:
  - Link picker UI and deletion-guard backend detection can be implemented concurrently behind shared contract.

## Phase 5: Observability, Operational Readiness, and Final Spec Closure
- Goal: Complete telemetry/AppSignal posture, finalize docs traceability, and run release-readiness checks.
- Tasks:
  - [x] Emit telemetry events for create/update/remove/resolve/failure/broken-click/delete-block paths.
  - [x] Ensure telemetry metadata excludes PII and includes project/section/resource scope identifiers.
  - [x] Wire AppSignal metrics for resolution latency and failure-rate counter signals used by dashboards/alerts.
  - [x] Update feature docs if implementation diverges from current PRD/FDD assumptions.
  - [x] Execute full feature regression pass across authoring, import/export, and delivery paths.
- Testing Tasks:
  - [x] Add/extend tests validating telemetry event emission and metadata shape.
  - [x] Run targeted and broader regression suites.
  - [x] Validate spec pack docs.
  - Command(s): `mix test test/oli/adaptive/dynamic_links/telemetry_test.exs test/oli/rendering/activity/html_test.exs test/oli/editing/activity_editor_test.exs test/oli_web/live/curriculum/container_test.exs` ; `.agents/scripts/spec_validate.sh --feature-dir docs/epics/adaptive_page_improvements/dynamic_links --check all`
- Definition of Done:
  - Required telemetry events emit correctly with safe metadata.
  - Alert thresholds are documented and metric names are available for AppSignal dashboard/alert configuration.
  - Spec docs and implemented behavior are aligned.
- Gate:
  - Regression and spec-validation commands pass; feature is ready for implementation handoff/review.
- Dependencies:
  - Phases 1-4 complete.
- Parallelizable Work:
  - Telemetry instrumentation and dashboard/alert setup can run in parallel with late regression hardening.

## Parallelisation Notes
- Primary dependency chain: Phase 1 -> Phase 2 -> Phase 3 -> Phase 4 -> Phase 5.
- Safe overlap:
  - Phase 2 export and ingest rewiring workstreams can run concurrently.
  - Within Phase 3, unresolved-link UX and memoization can run concurrently after rewrite baseline.
  - Within Phase 4, picker UI and deletion-link detection can run concurrently.
  - Within Phase 5, telemetry instrumentation and AppSignal dashboard setup can run concurrently.
- Highest-uncertainty work (contract shape and import rewiring) is front-loaded to reduce downstream churn.

## Phase Gate Summary
- Gate 1 (post Phase 1): Canonical adaptive link contract and serialization tests are green.
- Gate 2 (post Phase 2): Import/export rewiring integrity confirmed for adaptive links.
- Gate 3 (post Phase 3): Delivery rewrite/new-tab/fallback behavior verified in section context.
- Gate 4 (post Phase 4): Authoring UX and deletion guardrails verified with accessibility checks.
- Gate 5 (post Phase 5): Observability, regressions, and spec validation complete for handoff.
