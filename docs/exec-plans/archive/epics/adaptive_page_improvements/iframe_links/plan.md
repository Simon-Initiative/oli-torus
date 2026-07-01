# Iframe Links — Delivery Plan

Scope and guardrails reference:
- PRD: `docs/epics/adaptive_page_improvements/iframe_links/prd.md`
- FDD: `docs/epics/adaptive_page_improvements/iframe_links/fdd.md`

## Scope
Deliver MER-5212 by extending adaptive dynamic-link behavior to `janus-capi-iframe` sources with checkbox-based source-type UI (`External URL` vs `Page Link`), picker-only internal page selection, `resource_id`-based persistence, section-context delivery rewrite, unresolved fallback behavior, import/export rewiring, inbound dependency protection, and telemetry/AppSignal coverage while preserving external iframe URL behavior.

## Scenario Testing Contract
- Status: Required
- Infrastructure Support Status: Unsupported
- Scenario Infrastructure Expansion Required: Yes
- Scope (AC/workflows): AC-004, AC-005, AC-007, and AC-008 end-to-end flow from authoring internal iframe source selection through publish/section delivery resolution and unresolved-target fallback.
- Planned Artifacts:
  - `test/scenarios/delivery/adaptive_iframe_internal_link_resolution.scenario.yaml`
  - `test/scenarios/delivery/iframe_links_hooks.ex`
  - `test/scenarios/scenario_runner_test.exs`
- Validation Commands:
  - `mix test test/scenarios/validation/schema_validation_test.exs`
  - `mix test test/scenarios/scenario_runner_test.exs`
- Skill Handoff: Use $spec_scenario_expand first, then $spec_scenario

## LiveView Testing Contract
- Status: Not applicable
- Scope (events/states): N/A
- Planned Artifacts: N/A
- Validation Commands: N/A
- Rationale: Implementation surface is adaptive React + backend validation/rewiring/rendering, not a new LiveView interaction model.

## Non-Functional Guardrails
- Security/authz: picker options, save validation, rewiring, and delivery resolution must enforce project/section/tenant boundaries (FR-008).
- Reliability: unresolved internal iframe links degrade only iframe area and keep page interactive (FR-005).
- Data safety: no migration; JSON contract remains backward-compatible for legacy external `src` content (FR-006).
- Performance posture: use telemetry/AppSignal monitoring for resolution latency/failure budgets; do not add dedicated load/benchmark tests.
- Observability: emit/validate telemetry without PII and wire AppSignal metrics/alerts (FR-009).
- Feature flag posture: no feature flag for this slice, per PRD Section 11.

## Clarifications & Default Assumptions
- Internal iframe links target page resources only; screen-level deep links remain out of scope.
- The source-type selector in the Custom panel is implemented as checkbox-style controls aligned with popup editor interaction patterns.
- Internal-source metadata will align with dynamic-links semantics (`resource_id` source of truth, internal marker fields) and preserve external URL mode.
- Existing route contract remains `/sections/:section_slug/lesson/:page_revision_slug`.
- Delete warning modal will include inbound iframe references alongside existing adaptive text links.
- Fallback UX uses one standardized unresolved state for iframe area; final copy can be refined without changing core flow.

## FR/AC to Phase Traceability
| Requirement | Planned phase coverage | Verification stage |
|---|---|---|
| FR-001 / AC-001 | Phase 1 | Frontend picker-mode and API-backed selection tests |
| FR-002 / AC-002 | Phase 1, Phase 2 | Save contract normalization tests |
| FR-003 / AC-003 | Phase 2 | Validation rejection tests |
| FR-004 / AC-004 | Phase 3, Phase 5 | Delivery rewrite + scenario workflow tests |
| FR-005 / AC-005 | Phase 3, Phase 5 | Delivery fallback + scenario workflow tests |
| FR-006 / AC-006 | Phase 1, Phase 3 | External URL pass-through tests |
| FR-007 / AC-007 | Phase 4, Phase 5 | Rewiring + scenario workflow tests |
| FR-008 / AC-008 | Phase 2, Phase 3, Phase 4, Phase 5 | Authz/dependency/scope tests |
| FR-009 / AC-009 | Phase 5 | Telemetry/AppSignal verification |

## Phase 1: Authoring Contract and Picker UX Foundation
- Goal: Implement checkbox-based source-type switching for iframe source authoring with picker-only page-link mode and preserved external URL mode.
- Tasks:
  - [ ] Add checkbox-style source-type controls in iframe Custom panel (`External URL` and `Page Link`) matching popup editor behavior.
  - [ ] Extend `janus-capi-iframe` schema and authoring state with explicit source mode (`internal_page` vs `url`) and internal target metadata.
  - [ ] Render source editors conditionally by selected type (URL text field for external mode, page dropdown for page-link mode).
  - [ ] Wire picker data loading to `GET /api/v1/project/:project/link` and block manual slug entry path.
  - [ ] Keep external `src` editing flow unchanged when source mode is `url`.
  - [ ] Add i18n-ready strings and accessibility labels for source-mode controls and picker states.
- Testing Tasks:
  - [ ] Add frontend tests for source-type checkbox toggling, conditional source-field rendering, picker-only selection, loading/empty/error states, and external URL mode parity.
  - [ ] Validate API integration expectations for page list shape used by picker.
  - Command(s): `cd assets && yarn test src/components/parts/janus-capi-iframe` ; `mix test test/oli_web/controllers/api/resource_controller_test.exs`
- Definition of Done:
  - Source-type checkbox controls switch editor state between URL input and page dropdown correctly.
  - Authors can select in-project pages via picker in internal mode.
  - Manual slug entry is not possible in internal mode.
  - External URL authoring behavior is unchanged.
- Gate:
  - Phase 1 tests pass and authoring payload contract is stable for save pipeline work.
- Dependencies:
  - None.
- Parallelizable Work:
  - Frontend schema/UI updates and API contract verification can run concurrently once field names are finalized.

## Phase 2: Save Validation, Normalization, and Boundary Enforcement
- Goal: Enforce canonical `resource_id` persistence and reject invalid internal iframe targets at save time.
- Tasks:
  - [ ] Extend `ActivityEditor` adaptive traversal to validate `janus-capi-iframe` internal targets in relevant payload paths.
  - [ ] Normalize internal iframe source representation to canonical `resource_id`-based format.
  - [ ] Reject invalid, deleted, unauthorized, or out-of-project targets with clear validation errors.
  - [ ] Ensure legacy/external-only iframe content bypasses internal-target validation.
- Testing Tasks:
  - [ ] Add unit tests for canonical persistence (`resource_id` only) and rejection paths.
  - [ ] Add authorization-scope tests for out-of-project/out-of-tenant references.
  - Command(s): `mix test test/oli/editing/activity_editor_test.exs`
- Definition of Done:
  - Internal iframe saves persist canonical `resource_id` references.
  - Invalid or unauthorized internal targets fail save with explicit errors.
  - External URL mode remains unaffected.
- Gate:
  - Save-validation suite passes across valid, invalid, and boundary cases.
- Dependencies:
  - Phase 1 contract fields and source-mode semantics.
- Parallelizable Work:
  - Validation error messaging and normalization logic can be implemented in parallel with boundary test expansion.

## Phase 3: Runtime Rewrite, Fallback, and Context Parity
- Goal: Resolve internal iframe targets across authoring preview, instructor preview, and section delivery contexts; render safe fallback when unresolved.
- Tasks:
  - [ ] Extend adaptive delivery rewrite traversal to detect internal iframe markers and resolve to section lesson routes.
  - [ ] Add/maintain shared iframe source resolver behavior for preview-aware route rewrites before iframe load.
  - [ ] Rewrite internal iframe `/course/link/:slug` sources to preview-aware routes in authoring/instructor preview contexts.
  - [ ] Rewrite resolved iframe `src` to `/sections/:section_slug/lesson/:page_revision_slug`.
  - [ ] Implement unresolved fallback state contract for iframe surface only.
  - [ ] Add request-scoped memoization for repeated resource lookups.
- Testing Tasks:
  - [ ] Add delivery tests for successful rewrite in section context.
  - [ ] Add frontend resolver regression tests for preview and lesson route rewrites.
  - [ ] Add fallback tests for unresolved targets and ensure rest of adaptive page still renders.
  - [ ] Add regression tests confirming external iframe URLs are untouched.
  - Command(s): `mix test test/oli/rendering/activity/html_test.exs` ; `cd assets && yarn test --runInBand test/advanced_authoring/right_menu/component/iframe_source_resolver_test.ts`
- Definition of Done:
  - Internal iframe sources resolve correctly in preview and delivery contexts.
  - Unresolved targets trigger fallback without page-level failure.
  - Runtime rewrite and lookup behavior remains deterministic and memoized where applicable.
- Gate:
  - Runtime rewrite/fallback tests pass with preview parity and section-context authorization checks.
- Dependencies:
  - Phase 2 canonical internal metadata.
- Parallelizable Work:
  - Fallback UI-state marker handling and memoization can proceed concurrently after base rewrite logic lands.

## Phase 4: Interop Rewiring and Inbound Dependency Guardrails
- Goal: Preserve internal iframe references through import/export and include them in delete-warning dependency detection.
- Tasks:
  - [ ] Extend export and ingest rewiring traversal to include internal iframe source metadata fields.
  - [ ] Ensure rewiring remains idempotent and no-op for external URL mode.
  - [ ] Extend authoring dependency extraction to include inbound iframe references.
  - [ ] Update curriculum delete-warning source context to report iframe-based dependencies.
- Testing Tasks:
  - [ ] Add/import-export rewiring regression tests for iframe internal links and mixed internal/external content.
  - [ ] Add dependency detection and delete-warning tests including iframe references.
  - Command(s): `mix test test/oli/interop/rewire_links_test.exs test/oli/interop/ingest/processor/rewiring_test.exs test/oli/publishing/authoring_resolver_test.exs test/oli_web/live/curriculum/container_test.exs`
- Definition of Done:
  - Rewiring correctly remaps internal iframe references across project migration.
  - Inbound dependency checks block/warn on iframe-linked targets.
- Gate:
  - Interop and dependency-warning tests pass for happy-path and missing-map cases.
- Dependencies:
  - Phase 2 canonical metadata contract.
  - Phase 3 resolver expectations for delivery parity.
- Parallelizable Work:
  - Interop rewiring updates and dependency-scan updates can run concurrently, merging on shared test fixtures.

## Phase 5: Observability and Scenario Workflow Coverage
- Goal: Complete telemetry/AppSignal posture and required high-level scenario coverage.
- Tasks:
  - [ ] Extend adaptive dynamic-link telemetry emission for iframe authoring/delivery outcomes with non-PII metadata.
  - [ ] Wire AppSignal counters/distributions and alert configuration notes for latency/failure/fallback thresholds.
  - [ ] Use $spec_scenario_expand to add missing scenario infrastructure support for internal iframe-source authoring/resolution flow.
  - [ ] Then use $spec_scenario to author required scenario tests for authoring->publish->delivery and unresolved fallback workflow.
- Testing Tasks:
  - [ ] Add telemetry emission tests for create/update/remove/resolve/failure/fallback outcomes.
  - [ ] Add and validate scenario artifact coverage for AC-004/AC-005/AC-007/AC-008.
  - [ ] Run required scenario validation loop.
  - Command(s): `mix test test/oli/adaptive/dynamic_links/telemetry_test.exs` ; `mix test test/scenarios/validation/schema_validation_test.exs` ; `mix test test/scenarios/scenario_runner_test.exs`
- Definition of Done:
  - Telemetry and AppSignal posture satisfies PRD/FDD budgets and metadata hygiene.
  - Required scenario coverage is present and passing.
- Gate:
  - Telemetry tests and scenario validation commands pass.
- Dependencies:
  - Phases 2-4 implementation complete.
- Parallelizable Work:
  - Telemetry instrumentation and scenario infrastructure expansion can proceed in parallel until final scenario authoring depends on expansion completion.

## Phase 6: Final Regression and Spec-Pack Closure
- Goal: Confirm end-to-end readiness and keep spec artifacts synchronized for implementation handoff.
- Tasks:
  - [ ] Execute targeted regression across authoring, save validation, delivery, rewiring, and dependency warning flows.
  - [ ] Reconcile PRD/FDD/plan docs if implementation decisions changed.
  - [ ] Ensure `requirements.yml` statuses remain in sync through plan verification and master validation.
  - [ ] Capture rollout/rollback checklist for operational handoff (no feature flag).
- Testing Tasks:
  - [ ] Run integrated feature test sweep and spec validation/traceability gates.
  - Command(s): `mix test test/oli/editing/activity_editor_test.exs test/oli/rendering/activity/html_test.exs test/oli/interop/rewire_links_test.exs test/oli/interop/ingest/processor/rewiring_test.exs test/oli/publishing/authoring_resolver_test.exs test/oli_web/live/curriculum/container_test.exs` ; `.agents/scripts/spec_validate.sh --feature-dir docs/epics/adaptive_page_improvements/iframe_links --check all`
- Definition of Done:
  - End-to-end feature behavior is regression-tested and stable.
  - Spec pack documents and requirement traceability are aligned.
- Gate:
  - Full targeted regression and spec validation complete with no blocking failures.
- Dependencies:
  - Phases 1-5 complete.
- Parallelizable Work:
  - Documentation reconciliation and operational handoff checklist can run concurrently with late-stage regression reruns.

## Parallelisation Notes
- Core dependency chain: Phase 1 -> Phase 2 -> Phase 3 -> Phase 4 -> Phase 5 -> Phase 6.
- Parallel track A: In Phase 1, frontend picker UI and API contract verification can proceed concurrently.
- Parallel track B: In Phase 3, fallback-state rendering and memoization optimization can run concurrently after resolver rewrite baseline.
- Parallel track C: In Phase 4, interop rewiring and inbound dependency detection can be developed concurrently with shared fixture coordination.
- Parallel track D: In Phase 5, telemetry instrumentation and scenario infrastructure expansion can run in parallel; scenario authoring starts after expansion support is in place.

## Phase Gate Summary
- Gate 1: Picker-only authoring contract stable and Phase 1 tests green.
- Gate 2: Save validation/normalization enforces canonical `resource_id` and boundary checks.
- Gate 3: Runtime rewrite/fallback behavior verified for authoring preview, instructor preview, and section delivery contexts.
- Gate 4: Import/export rewiring and delete-warning dependency coverage verified.
- Gate 5: Telemetry posture and required scenario workflow coverage validated.
- Gate 6: Regression and spec-pack validation complete for implementation handoff.

## Operational Handoff Checklist (No Feature Flag)
- Rollout:
  - Deploy backend and assets together so authoring schema/UI and delivery rewrites stay in contract.
  - Run `mix compile` and targeted iframe-link regressions in CI before merge.
  - Verify AppSignal dashboards for adaptive dynamic-link `source` values (`activity_editor`, `iframe_authoring`, `iframe_delivery_render`, `curriculum_delete_modal_iframe`) remain within expected latency/failure budgets for 24 hours.
- Rollback:
  - Revert the feature commit set and redeploy backend + assets as one unit.
  - Republish affected projects if rollback crosses content-shape boundaries in authoring revisions.
  - Confirm external iframe URL mode remains functional after rollback by rerunning external-mode regression tests.
- Post-deploy verification:
  - Authoring: switch between `External URL` and `Page Link`, save, reload, and verify persisted mode/value.
  - Preview/delivery: validate iframe internal links resolve in authoring preview, section preview, and section lesson routes.
  - Dependency warnings: confirm curriculum delete modal lists iframe inbound references.

## Decision Log
### 2026-03-09 - Expand Phase 3 to Include Authoring Preview Rewrite
- Change: Updated Phase 3 goal, tasks, tests, and gate criteria to explicitly include authoring/instructor preview iframe route rewriting (not only section delivery rewrite).
- Reason: Implementation added a shared resolver to prevent preview-time `/course/link/*` requests from bypassing rewrite and causing route failures.
- Evidence: `assets/src/components/parts/janus-capi-iframe/sourceResolver.ts`; `assets/src/components/parts/janus-capi-iframe/ExternalActivity.tsx`; `assets/src/components/parts/janus-capi-iframe/CapiIframeAuthor.tsx`; `assets/test/advanced_authoring/right_menu/component/iframe_source_resolver_test.ts`.
- Impact: Phase 3 verification now requires preview parity checks, reducing risk of regressions between authoring preview and delivery runtime.

### 2026-03-09 - Scenario Infrastructure Expansion via JSON Activity Content
- Change: Added `create_activity` scenario support for `content_format: json` so adaptive activity payloads can be authored without TorusDoc converter constraints, and added hook-backed scenario assertions for iframe resolution/fallback/rewiring flow.
- Reason: Required Phase 5 scenario workflow needed adaptive iframe model setup and render assertions that existing TorusDoc-only activity creation could not express.
- Evidence: `lib/oli/scenarios/directives/activity_handler.ex`; `lib/oli/scenarios/directive_parser.ex`; `lib/oli/scenarios/directive_types.ex`; `priv/schemas/v0-1-0/scenario.schema.json`; `test/scenarios/delivery/adaptive_iframe_internal_link_resolution.scenario.yaml`; `test/scenarios/delivery/iframe_links_hooks.ex`.
- Impact: Phase 5 required scenario contract is now executable with deterministic, non-UI workflow coverage for AC-004/AC-005/AC-007/AC-008.

### 2026-03-10 - Phase 6 Traceability and Operational Closure
- Change: Added an explicit no-feature-flag rollout/rollback operational checklist and reconciled `requirements.yml` proof references to iframe-link implementation tests.
- Reason: Final-phase requirements verification auto-populated unrelated proofs; phase closure requires deterministic FR/AC-to-implementation evidence and handoff runbook.
- Evidence: `docs/epics/adaptive_page_improvements/iframe_links/requirements.yml`; this plan section `Operational Handoff Checklist (No Feature Flag)`.
- Impact: Phase 6 gate now has concrete operational validation/rollback steps and accurate requirement traceability evidence.
