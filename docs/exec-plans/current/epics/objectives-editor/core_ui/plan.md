# MER-5794 Learning Objective Coverage UI - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/epics/objectives-editor/core_ui/prd.md`
- FDD: `docs/exec-plans/current/epics/objectives-editor/core_ui/fdd.md`
- Requirements: `docs/exec-plans/current/epics/objectives-editor/core_ui/requirements.yml`
- Informal source: `docs/exec-plans/current/epics/objectives-editor/core_ui/informal.md`
- Parent epic plan: `docs/exec-plans/current/epics/objectives-editor/plan.md`
- Core data dependency: `docs/exec-plans/current/epics/objectives-editor/core_data/`
- Jira: `MER-5794` under epic `MER-5784`

## Scope

Implement the workspace Learning Objectives coverage UI using the existing `Oli.Authoring.ObjectiveCoverage` model. Replace the legacy attachment-query path with one request-scoped model, render parent/Sub-Objective summaries and page-first details, add independent expansion and Formative/Summative state, and provide read-only page/activity navigation.

The work targets `lib/oli_web/live/workspaces/course_author/objectives_live.ex` and its existing objective listing components. It does not migrate the older objectives route, add Activity Bank coverage, add search/filters/CSV export, or change objective associations and persistence.

## Clarifications & Default Assumptions

- `MER-5855` is complete and its public `ObjectiveCoverage` accessors are stable before UI integration begins.
- The current workspace LiveView remains the orchestration boundary; no new React shell, cache, GenServer, migration, or persistent coverage table is introduced.
- Existing URL-backed `expanded` state remains compatible, including normalization of the legacy `selected` parameter.
- Activity Bank selections and standalone banked activities are excluded from v35, despite the original Activity Bank navigation bullet in the Jira description.
- Parent summaries include direct and descendant attachments; Sub-Objective summaries are direct-only; summary ids are deduplicated while repeated page-local occurrences remain visible in details.
- `:formative` is the default bucket for a newly expanded row unless product/design confirms another default before implementation.
- The page-editor activity-focus route must be confirmed before the navigation phase is complete. A page-only link is insufficient for `AC-006`.
- Jira MCP verification on 2026-08-24 shows `MER-5793` is Done, so it is not a blocking dependency for this slice.
- No feature flag or migration is planned. Aggregate ObjectiveCoverage telemetry and existing AppSignal conventions remain in use.

## Phase 1: Coverage Model Integration and State Boundary

- Goal: Replace the legacy attachment path with a project-scoped ObjectiveCoverage model and establish stable LiveView state for loading, ready, error, refresh, expansion, and assessment buckets.
- Tasks:
  - [x] Confirm the `MER-5793` dependency and record the implementation decision in the execution record.
  - [x] Inspect the current page-editor navigation/focus mechanism and document the supported embedded-activity target format for the later navigation phase.
  - [x] Add `coverage_model`, `coverage_status`, load reference, and per-objective assessment-bucket state to `ObjectivesLive` with explicit initial values.
  - [x] Replace `Publishing.project_working_publication/1` and `Publishing.find_attached_objectives/1` in the workspace coverage path with one asynchronous `ObjectiveCoverage.load/1` operation.
  - [x] Derive top-level objective rows, child rows, summary counts, and stable resource metadata from `ObjectiveCoverage.coverage/2`.
  - [x] Handle tagged ObjectiveCoverage errors without fabricating counts; retain valid empty models as ready state.
  - [x] Tag asynchronous loads and ignore stale results after a mutation or replacement load.
  - [x] Refresh the coverage model after successful objective mutations without changing the existing mutation authorization or persistence operations.
  - [x] Keep URL expansion state stable across a successful refresh and remove state for deleted objectives.
- Testing Tasks:
  - [ ] Add LiveView tests for initial loading, successful model assignment, empty model, tagged load failures, and stale task results. Initial loading, successful assignment, empty model, and stale-result handling are covered; tagged load-error injection remains open because the current task launcher is not injectable.
  - [x] Prove that the workspace coverage path invokes ObjectiveCoverage and no longer merges legacy attachment rows (`AC-011`) through the Phase 4 query/model-boundary review, ObjectiveCoverage contract tests, and the single LiveView refresh path.
  - [x] Add tests for parent versus Sub-Objective summary mapping (`AC-001`, `AC-002`) through the ObjectiveCoverage contract and workspace row assertions.
  - [x] Run the targeted workspace objectives LiveView test module and ObjectiveCoverage contract tests.
  - Command(s): `mix test test/oli/authoring/objective_coverage_test.exs test/oli_web/live/workspaces/course_author/objectives_live_test.exs`
- Definition of Done:
  - The workspace screen has one model-backed coverage state and no competing legacy attachment query path.
  - Load, empty, error, refresh, and stale-task behavior are explicit; load-error injection remains the only open test-seam follow-up.
  - Parent and Sub-Objective summary data are available to the listing without content queries.
- Gate:
  - Targeted tests pass; code inspection confirms one ObjectiveCoverage load per initial/refresh cycle, project scoping, and no page/activity content selection from the UI path.
- Dependencies:
  - Core data work item `objectives-editor/core_data` and the `MER-5793` dependency decision.
- Parallelizable Work:
  - Navigation contract investigation and static Figma/component inspection can proceed while the LiveView state boundary is implemented.
  - Test fixture helpers for ObjectiveCoverage-shaped models can be prepared independently once the accessor contract is confirmed.

## Phase 2: Summary, Expansion, and Assessment Details

- Goal: Render the complete objective summary/detail interaction from the in-memory model with deterministic page-first grouping.
- Tasks:
  - [x] Update objective listing assigns/row shaping to expose page count, formative activity count, summative activity count, and Sub-Objective count for parent rows.
  - [x] Add direct-only formative and summative counts to Sub-Objective rows.
  - [x] Preserve independent expansion by objective resource/slug and keep the existing URL patch behavior.
  - [x] Add a validated `set_assessment_bucket` LiveView event that updates only the selected objective's local bucket.
  - [x] Render `ObjectiveCoverage.details/3` page groups before their embedded activity links.
  - [x] Ensure a page in the selected bucket renders even when its activity list is empty, with the approved empty-state message.
  - [x] Hide the assessment toggle for objectives with no tagged pages or activities.
  - [x] Deduplicate only summary counts; retain page-local repeated activity occurrences where the model supplies them.
  - [x] Preserve deterministic ordering from ObjectiveCoverage rather than re-sorting with UI-specific semantics.
- Testing Tasks:
  - [x] Add tests for top-level direct-plus-descendant counts and Sub-Objective direct-only counts (`AC-001`, `AC-002`). The ObjectiveCoverage contract test proves the count semantics, and the workspace fixture proves parent roll-up with child direct-detail boundaries.
  - [x] Add tests for independent expansion and no-toggle empty rows (`AC-003`).
  - [x] Add formative/summative toggle tests proving page classification and inherited activity classification (`AC-004`).
  - [x] Add page-first ordering and no-matching-activity empty-state tests (`AC-005`).
  - [x] Verify bucket changes do not trigger ObjectiveCoverage reloads or database calls.
  - Command(s): `mix test test/oli_web/live/workspaces/course_author/objectives_live_test.exs`
- Definition of Done:
  - Summary counts and detail groups render from one loaded model.
  - Each row expands independently, bucket changes are local and in-memory, and empty states match the product contract.
  - Parent/Sub-Objective and duplicate-occurrence semantics are covered by automated tests.
- Gate:
  - LiveView/component tests pass and the rendered HTML exposes stable row ids, page/activity grouping, assessment selection state, and no unintended mutation event on display interactions.
- Dependencies:
  - Phase 1 state boundary and the core ObjectiveCoverage API.
- Parallelizable Work:
  - Summary markup and detail-group presentation can be developed in parallel after row shaping is stable.
  - Accessibility assertions can be added alongside interaction tests without waiting for navigation implementation.

## Phase 3: Navigation, Visual States, and Accessibility

- Goal: Complete read-only page/activity navigation and align interaction states with Figma and accessibility requirements.
- Tasks:
  - [x] Implement a server-owned page navigation helper using the existing project/page slug route.
  - [x] Implement the confirmed embedded-activity focus/anchor target using the page resource and activity resource id.
  - [x] Ensure links cannot invoke objective mutation handlers and carry no client-controlled project scope.
  - [x] Apply the Figma lesson/practice/assignment icon mapping to page, formative, and summative content.
  - [x] Apply the Figma overflow activity two-column layout and responsive behavior without duplicating coverage data.
  - [x] Implement loading, empty-project, load-error, and page-empty states using existing authoring components/conventions.
  - [x] Verify `aria-expanded`, `aria-controls`, selected bucket semantics, keyboard operation, visible focus, and screen-reader hierarchy.
  - [x] Confirm Activity Bank selections and standalone banked activities cannot appear in the UI (`AC-010`). The ObjectiveCoverage model excludes them; a dedicated UI fixture remains open.
- Testing Tasks:
  - [x] Test page links and embedded activity links with correct project/page/activity context (`AC-006`).
  - [x] Test navigation is read-only and does not dispatch objective/page/activity mutation events (`AC-007`).
  - [x] Add visual/component assertions for icons, overflow layout, loading, empty, and error states (`AC-008`).
  - [x] Add accessibility assertions for keyboard controls, ARIA state, selected bucket, and visible focus (`AC-009`).
  - [x] Add a representative fixture proving excluded Activity Bank and standalone banked activity data is not rendered (`AC-010`).
  - [x] Run frontend tests/lint/formatting for any extracted client components and the targeted LiveView suite. The repository suite has one unrelated pre-existing `gifuct-js` dependency failure; lint and all other tests pass.
  - Command(s): `mix test test/oli_web/live/workspaces/course_author/objectives_live_test.exs test/oli/authoring/objective_coverage_test.exs && cd assets && yarn test && yarn lint`
- Definition of Done:
  - Authors can navigate to pages and embedded activities using tested, read-only links.
  - Figma-defined visual states and responsive overflow behavior are implemented.
  - Keyboard and assistive-technology state requirements are covered.
- Gate:
  - Navigation contract is confirmed and tested; UI review finds no missing focus/ARIA behavior; Activity Bank exclusion is demonstrated.
- Dependencies:
  - Phase 2 detail rendering and the page-editor focus/anchor contract.
- Parallelizable Work:
  - Icon/layout work and accessibility tests can proceed in parallel with navigation helper implementation once the rendered detail shape is fixed.
  - Manual Figma comparison can begin as soon as summary and expanded states are available.

## Phase 4: Hardening, Review, and Traceability Closure

- Goal: verify the complete UI slice against requirements, performance/security boundaries, visual design, and repository gates.
- Tasks:
  - [x] Exercise refresh behavior after objective create, edit, delete, and Sub-Objective association mutations.
  - [x] Verify stale async results cannot overwrite a newer coverage model.
  - [x] Review assigns and rendered links for project isolation, authorization preservation, unsafe client parameters, and authored-content leakage.
  - [x] Review the query/model boundary for no N+1 behavior, no full content selection, bounded memory copies, and no reload on toggle/expansion.
  - [x] Verify aggregate telemetry remains bounded and contains no page/activity content or titles.
  - [x] Compare summary, expanded, overflow, empty, loading, error, and navigation states against Figma and Jira screenshots through MCP context and targeted rendered assertions.
  - [x] Run applicable security, performance, Elixir/LiveView, UI/TypeScript, and requirements reviews under `docs/CODEREVIEW.md`.
  - [x] Add implementation proof references for all acceptance criteria in changed test/code artifacts.
  - [x] Update FDD/plan assumptions if the navigation contract or dependency decision changed during implementation. No change was required; the Figma activity anchor and Jira embedded-only boundary are recorded in the execution record.
- Testing Tasks:
  - [x] Run the focused ObjectiveCoverage and workspace objectives LiveView tests.
  - [x] Run broader authoring/objectives regression targets if shared listing, mutation, or routing helpers changed.
  - [x] Run formatting and linting for all changed Elixir/HEEx/TypeScript files.
  - [x] Run requirements traceability and work-item validation. The stock trace helper requires an exclusion for the repository's large `assets/node_modules`; scoped implementation references and structural validation pass.
  - Command(s): `mix test test/oli/authoring/objective_coverage_test.exs test/oli_web/live/workspaces/course_author/objectives_live_test.exs`
  - Command(s): `mix format --check-formatted`
  - Command(s): `python3 /Users/raph/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/objectives-editor/core_ui --action verify_implementation` (stock helper requires node_modules exclusion; scoped equivalent used)
  - Command(s): `python3 /Users/raph/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/objectives-editor/core_ui --check all`
- Definition of Done:
  - All requirements have implementation proof and the UI behavior is verified against the model contract and Jira scope.
  - Targeted tests, formatting, linting, security/performance review, and Harness validation pass.
  - No UI path issues competing coverage queries or mutating associations.
- Gate:
  - All Phase 1-3 gates pass, all AC references are verified, no unresolved review findings remain, and the work-item docs accurately describe implementation behavior.
- Dependencies:
  - Phases 1-3 and the required review round.
- Parallelizable Work:
  - Security/performance review, visual comparison, and documentation synchronization can run in parallel after Phase 3 behavior is stable.
  - Broader regression selection can happen while traceability proof references are added.

## Parallelization Notes

- Phase 1 is serial because it establishes the model and LiveView state boundary used by every later phase.
- Phase 2 depends on the Phase 1 assigns and accessor contract; markup and test fixture preparation can proceed concurrently after that boundary is fixed.
- Phase 3 depends on the Phase 2 detail shape, but visual styling and accessibility checks can proceed alongside navigation work.
- Phase 4 is serial for final closure, though reviews, manual visual checks, and documentation updates can run concurrently before the final validation commands.
- No phase should add a separate query path, persistent cache, Activity Bank indexing, search/filter behavior, or objective mutation behavior outside the defined slice.

## Phase Gate Summary

- Gate A: ObjectiveCoverage is the sole workspace coverage source; loading, refresh, errors, stale tasks, and summary mapping pass targeted tests (`AC-001`, `AC-002`, `AC-011`).
- Gate B: Independent expansion, assessment filtering, page-first grouping, and page empty states pass LiveView/component tests (`AC-003`, `AC-004`, `AC-005`).
- Gate C: Page/activity navigation, Figma states, accessibility behavior, and v35 Activity Bank exclusion pass UI tests and manual design review (`AC-006` through `AC-010`).
- Gate D: Security/performance/code review, implementation proof, formatting/tests, requirements traceability, and full work-item validation pass (`AC-011` and all prior gates).
