# Summary Tile - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/intelligent_dashboard/summary_tile/prd.md`
- FDD: `docs/exec-plans/current/epics/intelligent_dashboard/summary_tile/fdd.md`

## Scope
Implement `MER-5249` by replacing the current summary placeholder projection and placeholder tile UI with a projection-backed Summary region that renders scoped metrics, AI recommendation states, and recommendation controls in the existing Intelligent Dashboard LiveView surface. The plan assumes we should move implementation forward now, while keeping the recommendation contract edge and any remaining source ambiguities isolated behind adapter/projection boundaries so they can be clarified with the `MER-5305` owner before the ticket is closed.

## Clarifications & Default Assumptions
- Darren Siegel's Jira comment is the controlling technical clarification for this story, including optional-oracle incremental rendering, thumbs controls, and regenerate-in-flight disablement.
- The exact recommendation oracle key and payload shape are not yet final; implementation should isolate that dependency behind summary projection and tab-level integration code rather than hardcoding backend assumptions into the tile UI.
- `Average Class Proficiency` should be implemented with the current FDD default of `ObjectivesProficiency` as the canonical v1 source, while keeping the projector easy to adjust if final alignment changes.
- No feature flag is planned for this work item.
- Testing should follow repository guidance: targeted ExUnit and LiveView coverage first, then broader verification only as risk warrants.

## Phase 1: Summary Projection Refactor
- Goal: Replace the placeholder summary projection contract with a real summary projection and projector that derive metric-card, layout, and recommendation view models from optional upstream inputs. Covers `AC-002`, `AC-003`, `AC-005`, and `AC-009`.
- Tasks:
  - [ ] Replace legacy dependencies in `Oli.InstructorDashboard.DataSnapshot.Projections.Summary` with the summary-specific dependency set defined by the FDD.
  - [ ] Add `Oli.InstructorDashboard.DataSnapshot.Projections.Summary.Projector` to own metric derivation, card applicability, layout metadata, and recommendation-state shaping.
  - [ ] Implement card derivation for average student progress, average class proficiency, and average assessment score using existing scoped oracle payloads.
  - [ ] Implement partial/optional-input behavior so missing summary inputs degrade to hidden/unavailable subcomponents rather than a failed region.
  - [ ] Implement recommendation-state shaping for `thinking`, `beginning_course`, `ready`, and bounded unavailable/failure-safe states.
  - [ ] Keep recommendation contract adaptation narrow so the final `MER-5305` oracle key/payload can be swapped without rewriting the tile UI.
- Testing Tasks:
  - [ ] Add projection tests for optional oracle availability, hidden-card applicability, beginning-course fallback, and projector-owned aggregation behavior. Reference `AC-002`, `AC-003`, `AC-005`, `AC-009`.
  - Command(s): `mix test test/oli/instructor_dashboard/data_snapshot/projections`
- Definition of Done:
  - Summary projection no longer passes raw placeholder oracle payloads through untouched.
  - Projector tests prove that summary logic lives outside HEEx and that partial data yields valid output.
  - Recommendation state derivation is expressed through a normalized summary view model.
- Gate:
  - Projection tests pass and the resulting projection shape is stable enough for the tile UI to consume.
- Dependencies:
  - Depends on existing lane-1 oracle contracts already present in the repo; does not require final implementation of the recommendation oracle key to proceed.
- Parallelizable Work:
  - UI markup and shell wiring can be prepared in parallel if they consume only the documented projection contract and not the final recommendation adapter details.

## Phase 2: Dashboard Wiring And Summary Tile UI
- Goal: Replace the placeholder summary tile with a `live_component`, wire summary assigns through `IntelligentDashboardTab` and `shell.ex`, and render the scoped summary region below the global filter. Covers `AC-001`, `AC-004`, and part of `AC-007`.
- Tasks:
  - [ ] Update `IntelligentDashboardTab` payload building to expose `summary_projection`, `summary_projection_status`, and `summary_tile_state`.
  - [ ] Update the dashboard shell to mount the summary `live_component` with real assigns instead of the placeholder call.
  - [ ] Convert `SummaryTile` from a stateless placeholder function component to a `live_component` that renders prepared cards and recommendation content.
  - [ ] Implement metric-card layout and responsive card expansion rules based on visible-card count from the projection.
  - [ ] Implement accessible metric tooltip triggers and recommendation labeling semantics.
  - [ ] Align the rendered states with the Jira/Figma summary, thinking, and recommendation layouts as far as the current design input allows.
- Testing Tasks:
  - [ ] Add LiveView/component tests for summary placement below the scope navigator, visible-card layout changes, tooltip accessibility attributes, and recommendation label rendering. Reference `AC-001`, `AC-004`.
  - [ ] Add a scope-change render test that proves summary assigns can update without a page reload. Reference `AC-007`.
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard`
- Definition of Done:
  - The dashboard shell renders a real summary tile backed by projection data.
  - The summary region sits in the correct shell position and supports accessible static/intermediate states.
  - Placeholder-only summary UI code is removed or no longer used in the dashboard path.
- Gate:
  - LiveView tests confirm placement and accessible rendering behavior with real projection-driven assigns.
- Dependencies:
  - Depends on Phase 1 projection contract being stable.
- Parallelizable Work:
  - Visual polish and tooltip copy refinement can proceed in parallel with tab wiring once the component boundaries are fixed.

## Phase 3: Recommendation Interaction Wiring
- Goal: Implement recommendation-control wiring, in-flight state handling, and scope-update behavior without baking unstable `MER-5305` details into the tile UI. Covers `AC-006`, `AC-007`, and `AC-008`.
- Tasks:
  - [ ] Add summary-tile LiveView event handling for regenerate and sentiment submission.
  - [ ] Implement tile-local `regenerate_in_flight?` behavior so the regenerate control disables immediately and re-enables on success or failure.
  - [ ] Route thumbs/regenerate actions through tab-level integration points that can adapt to the final `MER-5305` contract.
  - [ ] Ensure recommendation regeneration failure preserves the previous recommendation while surfacing a bounded failure state.
  - [ ] Ensure scope changes replace summary recommendation content atomically and do not require a browser refresh.
  - [ ] Document any remaining recommendation-contract unknowns in code-level adapter boundaries or narrow comments rather than scattering assumptions through HEEx.
- Testing Tasks:
  - [ ] Add LiveView tests for regenerate disabled-in-flight, failure-safe previous recommendation preservation, event dispatch, and scope-change recommendation replacement. Reference `AC-006`, `AC-007`, `AC-008`.
  - [ ] Add focused tests for the recommendation adapter/view-model shaping boundary as soon as the provisional `MER-5305` contract is represented in code. Reference `AC-008`.
  - Command(s): `mix test test/oli_web/live/delivery/instructor_dashboard`
- Definition of Done:
  - Recommendation controls render and dispatch through stable UI boundaries.
  - In-flight regenerate behavior is visible and deterministic.
  - Recommendation interaction code remains localized enough to adjust once the colleague clarifies the final oracle/binding name.
- Gate:
  - Interaction tests pass and no recommendation-control logic depends directly on provider-specific payload assumptions in the tile component.
- Dependencies:
  - Depends on Phases 1 and 2.
  - Soft dependency on updated clarification from the `MER-5305` implementer before final ticket close, but not before initial UI wiring work.
- Parallelizable Work:
  - Telemetry instrumentation and docs/comments cleanup can proceed in parallel once event names and state transitions are stable.

## Phase 4: Hardening, Verification, And Closeout
- Goal: Finish targeted observability, regression coverage, implementation cleanup, and ticket-close readiness, including the remaining clarification pass with the `MER-5305` owner. Covers all ACs as final verification, especially `AC-004`, `AC-006`, `AC-007`, `AC-008`, `AC-009`.
- Tasks:
  - [ ] Add or finalize targeted telemetry/logging around summary projection failures and recommendation interaction outcomes.
  - [ ] Run implementation review against the PRD/FDD boundaries to ensure summary business logic did not leak back into HEEx or tab orchestration.
  - [ ] Reconcile the recommendation adapter with the exact `MER-5305` oracle/binding details once clarified.
  - [ ] Confirm whether the implemented proficiency-source and thumbs-lock behavior still match the intended final contract; adjust projector/adapter if needed.
  - [ ] Remove or tighten any temporary assumptions that were acceptable during implementation but not acceptable at ticket-close time.
  - [ ] Perform manual QA against Jira/Figma for light, dark, and thinking states plus keyboard/screen-reader checks.
- Testing Tasks:
  - [ ] Run the most targeted summary-related ExUnit/LiveView suites and broader impacted dashboard tests as needed.
  - [ ] Re-run requirement validation and work-item validation after the plan is complete and during closeout review.
  - Command(s): `mix test test/oli/instructor_dashboard/data_snapshot/projections test/oli_web/live/delivery/instructor_dashboard && python3 /Users/santiagosimoncelli/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/intelligent_dashboard/summary_tile --action master_validate --stage plan_present`
- Definition of Done:
  - Summary implementation is aligned with the clarified recommendation contract.
  - Tests and manual QA cover the critical summary states and recommendation interactions.
  - Remaining fragile points identified in PRD/FDD are either resolved in code or consciously documented as out-of-scope follow-up items.
- Gate:
  - The work item is ready for coding/closeout review with no hidden dependency on unresolved `MER-5305` contract assumptions.
- Dependencies:
  - Depends on Phases 1 through 3.
- Parallelizable Work:
  - Manual QA and telemetry verification can run in parallel with final recommendation-adapter cleanup once the backend contract clarification arrives.

## Parallelization Notes
- Projection work and shell/component scaffolding can overlap if both sides adhere to the FDD projection contract instead of reading each other's in-progress implementation details.
- Recommendation-adapter wiring should remain isolated so colleague clarifications from `MER-5305` can be absorbed late without destabilizing the rest of the tile.
- Manual visual QA should wait until the real component replaces the placeholder, but tooltip/accessibility assertions can be added earlier as LiveView tests.

## Phase Gate Summary
- Gate A: Summary projection and projector are in place, tested, and emit stable tile-ready data. (`AC-002`, `AC-003`, `AC-005`, `AC-009`)
- Gate B: Summary tile is mounted in the shell with accessible metric/recommendation rendering and scope-aware updates. (`AC-001`, `AC-004`, `AC-007`)
- Gate C: Recommendation controls are wired with regenerate-in-flight protection and bounded failure handling. (`AC-006`, `AC-007`, `AC-008`)
- Gate D: Telemetry, regression coverage, and final contract reconciliation with `MER-5305` are complete enough to close the ticket confidently. (all ACs)
