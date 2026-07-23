# MER-5416 Automated Basic Page Authored Content - Product Requirements Document

## 1. Overview
`MER-5416` expands automated basic page authoring coverage so Torus can validate publication-ready authored content against the regression spreadsheet's `MIXED` tab. The work item must also establish a reusable automation pattern for scenario-driven setup, Playwright authoring mutations, and post-Playwright scenario assertions against authoring preview and learner delivery.

The first implementation slice should be delivered as an infrastructure-first PR that proves the new pattern on one or two representative `MIXED` groups. Remaining groups should follow in additional PRs using the same pattern.

## 2. Background & Problem Statement
Lane 2 of the automated testing epic targets basic page authoring because manual release validation still depends heavily on browser-driven authoring checks. Torus already has some Playwright coverage for basic page authoring, but that coverage is broad and shallow compared to the 80-row `MIXED` matrix used in manual regression.

The Jira story and Darren's comment add an additional requirement beyond “more browser specs”: the system should support a three-stage flow where `Oli.Scenarios` bootstraps the authored world, Playwright mutates the page through the authoring UI, and a second scenario-based phase validates the resulting authored content through authoring preview and learner delivery.

The current repository does not yet provide a reusable `post-Playwright scenario` execution pattern. Without that infrastructure, the team would either stop at browser-visible checks or create one-off assertions that do not scale across the rest of the `MIXED` matrix.

## 3. Goals & Non-Goals
### Goals
- Establish a reusable automation pattern for `scenario setup -> Playwright authoring -> post-Playwright scenario assertions`.
- Support scenario-based assertions for authoring preview rendering and student delivery rendering after Playwright mutates authored content.
- Use the first PR to prove the pattern on one or two representative `MIXED` groups.
- Keep subsequent coverage expansion organized by grouped authoring behavior rather than spreadsheet row order.
- Reuse the existing authoring Playwright fixture, POMs, and scenario seeding infrastructure wherever possible.
- Keep all test worlds self-seeded and deterministic, with no dependency on pre-existing external state.

### Non-Goals
- The first PR is not expected to cover all 80 `MIXED` rows.
- Adaptive authoring and adaptive delivery are out of scope.
- Instructor preview is not the target preview surface for this work item.
- This work item does not attempt to replace all browser assertions with scenario-only coverage; Playwright remains part of the pattern.
- This PRD does not prescribe the exact contents of every follow-up PR beyond grouped coverage boundaries.

## 4. Users & Use Cases
- QA and release engineering: Need automated evidence that authored basic page content is persisted and rendered correctly without a full manual pass across the `MIXED` matrix.
- Course authors: Need confidence that common basic page authoring operations produce correct preview and learner-facing results after publication.
- Engineering teams working on authoring regressions: Need a reusable infrastructure pattern so new matrix rows can be automated without inventing a fresh orchestration flow each time.
- Future Playwright contributors: Need shared helpers and a stable two-phase scenario pattern rather than ad hoc one-off test wiring.

## 5. UX / UI Requirements
- Browser automation must operate through the existing course authoring UI entry points for basic page editing.
- The system must support validating the authoring preview surface as the preview authority for this work item.
- The system must support validating learner delivery rendering in a published section context after authoring changes are made.
- Follow-up coverage should group similar authoring behaviors together so helper reuse is practical and test failures remain diagnosable.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Reliability: The new test pattern must be deterministic enough for repeated automation use and must avoid reliance on manually pre-created state.
- Compatibility: Existing Playwright specs that only use scenario seeding must continue to work without adopting the new post-Playwright phase.
- Maintainability: The first slice must prefer shared fixture and helper extension over one-off orchestration embedded in a single spec.
- Performance: The additional scenario phase should be scoped narrowly enough to keep the first slice practical to run as targeted browser automation.
- Security: Scenario execution must continue to use the existing authorized internal test boundary; no new public runtime path should be introduced for production use.
- Accessibility: No new end-user UI is being introduced, but preview and delivery assertions should prefer semantic selectors or rendered-state checks where practical.

## 9. Data, Interfaces & Dependencies
- Depends on the existing Playwright scenario seed endpoint in `lib/oli_web/controllers/playwright_scenario_controller.ex`.
- Depends on the existing Playwright fixture and request helper in:
  - `assets/automation/src/core/fixture/my-fixture.ts`
  - `assets/automation/src/core/seedScenario.ts`
- Depends on existing basic page authoring helpers in:
  - `assets/automation/src/systems/torus/tasks/CurriculumTask.ts`
  - `assets/automation/src/systems/torus/pom/page/BasicPracticePagePO.ts`
  - `assets/automation/src/systems/torus/pom/page/PagePreviewPO.ts`
- May require new scenario directives, hooks, or orchestration support to:
  - execute a scenario after Playwright mutations
  - perform authoring preview assertions
  - perform learner delivery assertions
- Uses the `MIXED` spreadsheet tab as the coverage source of truth for grouped follow-up slices.

## 10. Repository & Platform Considerations
- The repository testing strategy prefers scenarios first, LiveView where appropriate, and Playwright only where browser behavior matters. This work item is explicitly a browser-critical authoring lane, but should still keep setup and deep assertions close to the scenario boundary.
- The Torus frontend is a mixed Phoenix, LiveView, and targeted browser-app system. The tests must extend the existing authoring surface rather than inventing a separate harness.
- Scenario infrastructure is already a first-class integration-testing mechanism in this repository, so any post-Playwright assertion phase should fit the existing `Oli.Scenarios` model rather than bypass it.
- The work item naturally belongs under `docs/exec-plans/current/epics/automated_testing/`, and follow-up slices should remain traceable to `MER-5416` rather than becoming disconnected one-off browser specs.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

The rollout strategy is phased delivery by PR:
- PR 1 introduces the infrastructure pattern plus one or two representative `MIXED` groups.
- Later PRs extend coverage across the remaining grouped `MIXED` slices using the same pattern.

No production feature rollout or data migration is expected beyond any internal test infrastructure changes required by the implementation.

## 12. Telemetry & Success Metrics
- Success is measured first by the existence of a reusable post-Playwright scenario pattern that can be consumed by later `MER-5416` slices.
- Success is measured second by replacing manual validation for at least one or two representative `MIXED` groups with deterministic automated evidence.
- Operational visibility should rely on existing logging and scenario execution feedback so failures in the second scenario phase are diagnosable.
- A successful outcome for the full work item is that the remaining `MIXED` groups become straightforward coverage additions rather than new infrastructure projects.

## 13. Risks & Mitigations
- Risk: The team conflates authoring preview with instructor preview. Mitigation: keep author preview explicit in test helpers, requirements, and scenario assertions.
- Risk: The first PR becomes too large by trying to absorb the full matrix. Mitigation: require the first PR to stop after infrastructure plus one or two representative groups.
- Risk: New scenario orchestration breaks existing scenario-seeded Playwright tests. Mitigation: keep the new phase additive and backwards compatible with current fixture usage.
- Risk: The initial representative groups are too simple and fail to prove the pattern. Mitigation: choose one or two groups with enough settings and rendering richness to exercise persisted, preview, and delivery surfaces.
- Risk: Later groups drift into a parallel style. Mitigation: require reuse of the initial fixture and helper extensions in follow-up slices.

## 14. Open Questions & Assumptions
### Open Questions
- Which one or two `MIXED` groups should be the first slice: a lower-complexity pair such as `IMAGE` and `CODEBLOCK`, or another pair with better infrastructure signal?
- Should the second scenario phase be implemented as a new endpoint action, a fixture-level helper, or an extension of the existing scenario execution contract?
- Do authoring preview assertions need new scenario directives, or can they be expressed through hooks against existing preview routes and render boundaries?

### Assumptions
- `MER-5416` is now a multi-PR work item, not a single small enhancement.
- The first PR's primary success condition is proving the reusable pattern, not maximizing row count.
- The `MIXED` spreadsheet tab is the authoritative coverage backlog for follow-up slices.
- Full coverage expansion will be grouped by shared authoring behavior such as `INLINE`, `TABLE`, or media/embed families.

## 15. QA Plan
- Automated validation:
  - validate the new work item's `requirements.yml` and `prd.md` through the harness validation scripts
  - add targeted Playwright coverage for the initial representative `MIXED` groups
  - add scenario validation and execution coverage for any new post-Playwright scenario mechanism
  - verify existing scenario-seeded Playwright specs remain green or unaffected
- Manual validation:
  - inspect the first slice's authoring preview and learner delivery behavior only as a sanity check during development
  - confirm the grouped follow-up plan matches the `MIXED` CSV inventory and does not silently drop uncovered rows

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
