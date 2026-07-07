# MER-5486 implementation plan

Each phase is intended to map to a separate commit. Phase 0 is the discovery and documentation work already completed.

## Phase 0 - Discovery and planning

Deliverables:

- `docs/exec-plans/current/mer-5486/informal.md`
- `docs/exec-plans/current/epics/automated_testing/mer-5486-testing-plan.md`
- `docs/exec-plans/current/epics/automated_testing/mer-5486-implementation-plan.md`

Outcome:

- Define the coverage target.
- Identify source code, required data, and scenario infrastructure gaps.

## Phase 1 - Scenario assertion infrastructure for dashboard snapshots

Goal:

- Enable instructor-facing YAML assertions for the dashboard.

Work:

- Add fields to `Oli.Scenarios.DirectiveTypes.AssertDirective`.
- Extend `Oli.Scenarios.DirectiveParser` and `priv/schemas/v0-1-0/scenario.schema.json`.
- Create a shared assertion module, for example `Oli.Scenarios.Directives.Assert.InstructorDashboardAssertion`, or modules per capability.
- Resolve section and scope from YAML:
  - `scope: "course"`
  - `scope: {container: "Foundations Unit"}`
  - optionally `scope: "container:<id>"` for advanced cases.
- Call `Oli.InstructorDashboard.DataSnapshot.get_or_build/2` with the correct consumer/dependency profile for each assertion.
- Compare nested expectations with float tolerance.
- Failure messages should name the assertion, section, scope, expected path, and actual value.

Questions/challenges:

- Decide whether to implement five physical assertion keys or a common key with sub-shapes. The ticket prefers separate names. Do not add a standalone `instructor_dashboard_proficiency` unless an equivalent visible surface is confirmed.
- Decide the exact YAML shape for nested rows/buckets.
- Confirm whether `summary` should accept partial projections or require ready projections for these tests.

Suggested verification:

- Parser unit tests in `test/scenarios/directives`.
- Schema validation tests.
- A small unit test with runtime stubs if helpful to isolate comparison logic.

Commit target:

- "[MER-5486] Add instructor dashboard scenario assertions"

## Phase 2 - Data readiness support

Goal:

- Ensure dashboard data is ready after `answer_question` / `finalize_attempt` without sleeps.

Work:

- Run a small existing scenario and verify whether `resource_summary` is updated synchronously in the test environment.
- If not deterministic, add an official directive or hook, for example:
  - `dashboard_analytics_ready`
  - `drain_snapshots`
  - or a `wait` extension that is not based on real elapsed time.
- Prefer using `Oli.Delivery.Snapshots.Worker.perform_now/2` with known part attempt guids or draining the Oban `:snapshots` queue.
- Document the directive in `test/support/scenarios/docs/student_simulation.md` or new dashboard scenario docs.

Questions/challenges:

- `answer_question` stores the evaluation result but does not currently store part attempt guids in a convenient way for replay.
- `finalize_attempt` stores `FinalizationSummary.part_attempt_guids` for graded pages.
- Practice-page analytics may depend on snapshots created by `Evaluate.evaluate_activity/4`; confirm in test.

Suggested verification:

- Test proving the directive leaves `Oli.Analytics.Summary.ResourceSummary` ready for `ProgressProficiency`.
- Do not use `Process.sleep`.

Commit target:

- "[MER-5486] Add deterministic dashboard analytics readiness support"

## Phase 3 - Shared instructor dashboard scenario setup

Goal:

- Create reusable base YAML for dashboard scenarios.

Work:

- Create `test/scenarios/instructor_dashboard/setup.yaml` or `base.scenario.yaml`.
- Model project, objectives, units, pages, MCQs, and graded page(s).
- Create instructor and students.
- Enroll all required users.
- Add existing `structure` assertions to protect the setup.

Questions/challenges:

- Balance page count against performance. Real proficiency needs 3 first attempts per objective.
- Decide whether graded pages use real activities + finalize or `complete_scored_page`.

Suggested verification:

- `mix run -e '...Oli.Scenarios.validate_file("test/scenarios/instructor_dashboard/base.scenario.yaml")...'`
- New ExUnit runner using `Oli.Scenarios.execute_file/2`, without fixture wrappers.

Commit target:

- "[MER-5486] Add instructor dashboard scenario base data"

## Phase 4 - Core dashboard correctness scenarios

Goal:

- Cover the main acceptance criteria: progress, student support, and the proficiency signal used by summary/challenging objectives.

Work:

- Scenario `course_summary_and_support.scenario.yaml`:
  - Executes excelling/on-track/struggling/no-data student patterns.
  - Assertions: summary, progress, student support.
- Scenario `proficiency_and_challenging_objectives.scenario.yaml`:
  - Forces High/Medium/Low distributions by objective.
  - Assertions: summary `average_class_proficiency` and challenging objectives. Do not create a standalone `instructor_dashboard_proficiency` panel assertion unless an equivalent visible surface exists.

Questions/challenges:

- Adjust expected numbers after observing real `Metrics` results.
- Keep YAML readable; avoid huge expected payloads.

Suggested verification:

- Schema validation for all new files.
- `mix test test/scenarios/instructor_dashboard/instructor_dashboard_test.exs`

Commit target:

- "[MER-5486] Cover instructor dashboard progress proficiency and support scenarios"

## Phase 5 - Assessment dashboard scenario

Goal:

- Validate assessment/activity outcomes shown by the dashboard.

Work:

- Scenario `assessment_outcomes.scenario.yaml`.
- Create graded quiz/quizzes.
- Simulate known scores.
- Assertions: assessment rows, completion, score metrics, and histogram.
- If `complete_scored_page` is used, leave a note in YAML/docs explaining why it is acceptable, or migrate it to real finalization.

Questions/challenges:

- The `Grades` oracle only considers pages with `graded == true` and `ResourceAccess.score/out_of`.
- If real finalization generates unexpected scores because of max attempts/scoring strategy, adjust assessment settings setup.

Suggested verification:

- Targeted scenario test.
- Optional: compare with existing `gradebook` assertion for sanity.

Commit target:

- "[MER-5486] Cover instructor dashboard assessment scenario"

## Phase 6 - Scope and empty-state coverage

Goal:

- Cover relevant non-minimum gaps.

Work:

- Scenario `container_scope_filtering.scenario.yaml`:
  - Progress, assessments, and challenging objectives filtered by unit.
- Scenario `initial_empty_dashboard.scenario.yaml`:
  - Enrolled students without activity.
  - No-data support bucket and zero progress.
- Optional: custom student support thresholds.

Questions/challenges:

- Do not overload the default suite if it becomes slow. Mark nightly only if there is evidence.

Suggested verification:

- Full instructor dashboard scenario runner.
- `mix test test/scenarios/validation/schema_validation_test.exs`

Commit target:

- "[MER-5486] Add instructor dashboard scope and empty state scenarios"

## Phase 7 - Cleanup and docs

Goal:

- Leave the suite maintainable.

Work:

- Document new dashboard assertions in `test/support/scenarios/docs/`.
- Review YAML names so they remain product/instructor-facing.
- Remove or update `docs/exec-plans/current/mer-5486/informal.md` if it is no longer useful.
- Run formatting and targeted tests.

Suggested verification:

- `mix format`
- `mix test test/scenarios/instructor_dashboard/instructor_dashboard_test.exs`
- `mix test test/scenarios/validation/schema_validation_test.exs`

Commit target:

- "[MER-5486] Document instructor dashboard scenario assertions"

## Guardrails

- Do not use fixtures/factories/mocks to create project/section/enrollments/attempts in new scenario tests.
- Do not use `execute_with_fixtures` or fixture-backed helpers.
- Prefer YAML assertions over Elixir-side assertions.
- Do not use fixed sleeps for async readiness.
- Keep YAML names free of "oracle".

