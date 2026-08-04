# MER-5416 Automated Basic Page Authored Content - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/automated_testing/mer-5416/prd.md`
- FDD: `docs/exec-plans/current/epics/automated_testing/mer-5416/fdd.md`
- Requirements: `docs/exec-plans/current/epics/automated_testing/mer-5416/requirements.yml`
- Coverage inventory and grouping notes: `docs/exec-plans/current/epics/automated_testing/mer-5416-approach.md`
- Row-complete workflow coverage matrix: `docs/exec-plans/current/epics/automated_testing/mer-5416/mixed_coverage_matrix.md`

## Scope
Deliver `MER-5416` as a multi-PR work item that first establishes the reusable `scenario -> playwright_action -> scenario` automation pattern and then expands `MIXED`-tab coverage by grouped authoring behavior. The first implementation PR is intentionally limited to infrastructure plus one or two representative groups so the workflow pattern is proven before broader expansion.

This plan covers:
- the TypeScript-side workflow runner and step contracts
- additive backend support needed for repeated scenario execution and post-Playwright assertions
- authoring preview and learner delivery assertion support
- grouped follow-up expansion across the remaining `MIXED` coverage families

This plan does not attempt to deliver all 80 spreadsheet rows in one PR.

Coverage naming note:
- `Phase` in this document means an implementation stage.
- `Slice` in `mixed_coverage_matrix.md` means a coverage batch of spreadsheet rows.
- Slices are not intended to align 1:1 with phases.

## Clarifications & Default Assumptions
- `AC-001`, `AC-002`, and `AC-003` are owned primarily by the infrastructure-first PR.
- `AC-004` and `AC-008` require one or two representative groups in the first PR; default assumption is to prefer groups with moderate complexity and strong settings/render signal.
- `AC-005` means the first PR must stop after proving the pattern and documenting grouped follow-up slices rather than absorbing broad row count.
- `AC-006` requires explicit regression verification against at least one existing scenario-seeded Playwright spec.
- `AC-007` means author preview must remain semantically distinct from instructor preview in both docs and assertions.
- `AC-009` requires durable documentation in `assets/automation/WORKFLOWS.md` during the first implementation PR.
- `AC-010` requires a row-complete `MIXED` matrix that remains current through the initial PR and the immediate follow-up PR.
- Default first-slice candidates are `IMAGE` plus `CODEBLOCK` unless deeper implementation reconnaissance finds a better pair.

## Phase 1: Finalize Workflow Contracts
- Goal: Lock the v1 workflow DSL, step contracts, output model, and first-slice group choice so implementation can proceed without reopening the architecture. Supports `AC-004`, `AC-005`, `AC-007`, and `AC-009`.
- Tasks:
  - [ ] Confirm the v1 workflow declaration shape:
    - `scenario`
    - `playwright_action`
  - [ ] Confirm the workflow state contract for global params and per-step outputs.
  - [ ] Confirm interpolation rules and failure behavior for missing references.
  - [ ] Choose the first one or two representative `MIXED` groups for PR 1.
  - [ ] Confirm that top-level `hook` steps are out of scope for v1 and that custom assertion logic stays inside scenario steps.
  - [ ] Create the row-complete `MIXED` workflow coverage matrix and assign every spreadsheet row to a target slice (`AC-010`).
- Testing Tasks:
  - [ ] Reconcile the chosen PR 1 groups against the `MIXED` CSV inventory and current repo coverage.
  - Command(s): `rg -n "MIXED|IMAGE|CODEBLOCK|TABLE|INLINE" docs/exec-plans/current/epics/automated_testing assets/automation/tests/torus/course_authoring`
- Definition of Done:
  - v1 step types, outputs, interpolation, and first-slice groups are explicitly fixed for implementation.
  - Author-preview semantics are unambiguous for PR 1 (`AC-007`).
  - The matrix contains all 80 spreadsheet rows with non-empty workflow status and target slice fields (`AC-010`).
- Gate:
  - Gate A: implementation starts only after the first-slice groups and contracts are stable enough to avoid workflow-shape churn.
- Dependencies:
  - PRD and FDD complete.
- Parallelizable Work:
  - Lightweight scenario-surface reconnaissance for author-preview assertions can proceed in parallel with final group selection.

## Phase 2: Build The Workflow Runner And Additive Scenario Support
- Goal: Implement the reusable orchestration foundation for repeated scenario execution around Playwright authoring. Supports `AC-001`, `AC-006`, and `AC-009`.
- Tasks:
  - [ ] Add the workflow runner under `assets/automation/src/core/` with:
    - workflow parsing
    - sequential step execution
    - serializable workflow state
    - arbitrary-length linear step support
  - [ ] Add a scenario step adapter that reuses the existing scenario execution endpoint for repeated calls.
  - [ ] Add a Playwright action registry and action-step adapter.
  - [ ] Extend `assets/automation/src/core/fixture/my-fixture.ts` with a new `runWorkflow(...)` helper while preserving `seedScenario(...)`.
  - [ ] Keep the new runner additive so current `seedScenario` consumers remain unchanged (`AC-006`).
  - [ ] Add or adjust scenario endpoint/response support only if needed to improve repeated-step outputs or params handling.
  - [ ] Document the infrastructure contract in `assets/automation/WORKFLOWS.md` (`AC-009`).
- Testing Tasks:
  - [ ] Add targeted tests for workflow parsing/interpolation if cheap in the current automation stack.
  - [ ] Run at least one existing scenario-seeded Playwright spec to prove additive compatibility (`AC-006`).
  - Command(s): `cd assets/automation && npx playwright test tests/torus/course_authoring/course-authoring.spec.ts --grep "Content:"`
- Definition of Done:
  - The runner can execute at least `scenario -> playwright_action` successfully.
  - Existing non-workflow scenario-seeded specs still run unchanged (`AC-006`).
  - `assets/automation/WORKFLOWS.md` exists or is updated with the v1 contract (`AC-009`).
- Gate:
  - Gate B: no first-slice group coverage starts until the runner and additive compatibility are proven.
- Dependencies:
  - Phase 1 complete.
- Parallelizable Work:
  - Backend scenario assertion helpers can be prototyped in parallel as long as they do not require workflow-shape changes.

## Phase 3: Add Post-Playwright Author Preview And Learner Delivery Assertions
- Goal: Prove the second scenario phase can validate preview and delivery after browser mutations. Supports `AC-001`, `AC-002`, `AC-003`, and `AC-007`.
- Tasks:
  - [ ] Implement the scenario-based post-Playwright assertion path for author preview.
  - [ ] Implement the scenario-based post-Playwright assertion path for learner delivery in a published section context.
  - [ ] Add or refine scenario hooks/directives only if current scenario surfaces cannot express the required assertions cleanly.
  - [ ] Keep preview assertions aligned to author preview and not instructor preview (`AC-007`).
  - [ ] Ensure workflow outputs from browser steps can feed the scenario assertion phase.
- Testing Tasks:
  - [ ] Add targeted scenario tests for any new assertion helpers, hooks, or directives.
  - [ ] Prove one workflow can execute `scenario -> playwright_action -> scenario`.
  - Command(s): `mix test test/scenarios/features` 
- Definition of Done:
  - Author preview can be asserted without manual browser inspection (`AC-002`).
  - Learner delivery can be asserted without manual browser inspection (`AC-003`).
  - Workflow alternation works across both pre- and post-browser scenario phases (`AC-001`).
- Gate:
  - Gate C: representative group implementation may proceed only after both assertion surfaces are technically viable.
- Dependencies:
  - Phase 2 complete.
- Parallelizable Work:
  - Separate assertion helpers for preview and delivery can be built in parallel if they consume the same workflow outputs.

## Phase 4: Deliver PR 1 With Representative `MIXED` Groups
- Goal: Use the new pattern to automate one or two representative `MIXED` groups end to end. Supports `AC-004`, `AC-005`, `AC-008`, and `AC-009`.
- Tasks:
  - [ ] Create setup scenario(s) for the chosen representative groups.
  - [ ] Implement Playwright actions for the chosen representative groups using existing authoring helpers where possible.
  - [ ] Implement post-Playwright scenario assertion files for persisted state, author preview, and learner delivery as required by the chosen rows (`AC-008`).
  - [ ] Keep the first PR bounded to the selected groups only (`AC-005`).
  - [ ] Update the work-item docs to record which groups remain for follow-up slices (`AC-009`).
  - [ ] Update the matrix so all PR 1 rows move from `planned` to `covered` with concrete workflow test references (`AC-010`).
- Testing Tasks:
  - [ ] Run the new workflow-driven Playwright specs for the representative groups.
  - [ ] Re-run at least one unaffected existing scenario-seeded authoring spec (`AC-006`).
  - Command(s): `cd assets/automation && npx playwright test tests/torus/course_authoring`
- Definition of Done:
  - One or two representative groups are automated end to end using the new pattern (`AC-004`).
  - Those groups validate persisted authoring state, preview rendering, and learner delivery rendering where applicable (`AC-008`).
  - The PR clearly documents that remaining groups are follow-up work (`AC-005`, `AC-009`).
  - The matrix reflects the exact PR 1 covered rows and leaves no undocumented spreadsheet rows (`AC-010`).
- Gate:
  - Gate D: PR 1 is ready only when the new pattern has been exercised by real `MIXED` coverage rather than infrastructure-only smoke checks.
- Dependencies:
  - Phase 3 complete.
- Parallelizable Work:
  - If two representative groups are chosen, their authored-content actions and assertion files can be implemented in parallel once the runner and assertion surfaces are stable.

## Phase 5: Expand Coverage Across Remaining Grouped Slices
- Goal: Cover the remaining `MIXED` groups in follow-up PRs using the proven workflow pattern. Supports `AC-005` and `AC-009`, while extending the reusable value of `AC-001` through `AC-008`.
- Tasks:
  - [ ] Plan follow-up PRs by grouped authoring behavior instead of spreadsheet row order:
    - `INLINE + LIST + CORE`
    - `TABLE`
    - `IMAGE + FIGURE` if not chosen in PR 1
    - `YOUTUBE + VIDEO + WEBPAGE`
    - `DIALOG + CONJUGATION + DESCRIPTIONLIST + DEFINITION`
    - remaining singletons as appropriate
  - [ ] Reuse the workflow runner, action registry, and scenario assertion pattern for each slice.
  - [ ] Extend `assets/automation/WORKFLOWS.md` only when the contract itself changes, not for every new row family.
  - [ ] Keep residual uncovered rows visible in work-item docs until the matrix is exhausted.
  - [ ] Keep `mixed_coverage_matrix.md` current as each follow-up slice lands, starting with the immediate follow-up PR after Slice 1 (`AC-010`).
- Testing Tasks:
  - [ ] Run targeted Playwright coverage per grouped PR.
  - [ ] Run targeted scenario tests when new hooks/directives are added for later groups.
  - Command(s): `cd assets/automation && npx playwright test tests/torus/course_authoring`
- Definition of Done:
  - Follow-up PRs are organized around shared authoring behavior and helper reuse (`AC-009`).
  - No follow-up PR re-litigates the workflow contract unless a real gap is discovered.
  - The matrix remains row-complete and current after each follow-up slice, with the immediate next PR expected to preserve that invariant (`AC-010`).
- Gate:
  - Gate E: later groups may merge only if they use the established pattern rather than introducing a second automation style.
- Dependencies:
  - Phase 4 complete.
- Parallelizable Work:
  - Later grouped PRs can proceed in parallel after PR 1 merges if they do not change the workflow contract itself.

## Parallelization Notes
- Phases 2 and 3 have limited safe overlap, but assertion-surface work should not force changes to the step contract after Phase 1 closes.
- Within Phase 4, two representative groups can be split across contributors if they share the same workflow runner base.
- Phase 5 follow-up slices are the main parallelization opportunity once the pattern is proven and documented.

## Phase Gate Summary
- Gate A: workflow v1 contract and first-slice groups are fixed.
- Gate B: additive runner infrastructure works and existing scenario-seeded specs remain compatible. Covers `AC-006` and `AC-009`.
- Gate C: post-Playwright preview and delivery assertion phases are viable. Covers `AC-001`, `AC-002`, `AC-003`, and `AC-007`.
- Gate D: PR 1 proves the full pattern on one or two representative `MIXED` groups. Covers `AC-004`, `AC-005`, and `AC-008`.
- Gate E: grouped follow-up PRs expand coverage using the established pattern rather than inventing a parallel style. Covers `AC-009`.
