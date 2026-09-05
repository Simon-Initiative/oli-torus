# Phase 16 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling`
Phase: `16 - Integrated Reconciliation and Final Verification`

## Completed

- [x] Removed the obsolete `DecisionPoint`, `DecisionPointCondition`, and candidate schema/helper modules plus virtual point fields.
- [x] Renamed the delivery strategy module to `ExperimentControlledStrategy`; retained `upgrade_decision_point` only as the required legacy content-strategy alias.
- [x] Migrated scenario hooks and experiment-adjacent xAPI, page lifecycle, duplication, and Alternatives fixtures to direct experiment ownership.
- [x] Reconciled authoring and reporting terminology with one group, one policy state, and many interventions.
- [x] Removed the redundant weighted-random intervention pre-read and reused assignment counts and preloaded reward associations on hot paths.
- [x] Denied non-collaborator access to authoring graphs and Alternatives discovery, and required complete placement identity for assignment reads.
- [x] Consolidated reward binding, assignment, condition, experiment, and duplicate-reward discovery into one query before the required policy-state transactions.

## Query-Plan Verification

`EXPLAIN (ANALYZE, BUFFERS)` was run against the final test schema for the four integrated query shapes. The planner selected:

- active resolution: `experiment_definitions_active_project_idx` and `experiment_sections_delivery_relevance_idx`;
- sticky lookup: `experiment_assignments_intervention_sticky_idx` and `experiment_interventions_content_lookup_idx`;
- reward lookup: assignment sticky, intervention primary-key, and `experiment_assessment_bindings_intervention_idx` scans;
- policy snapshot: `experiment_conditions_experiment_id_idx` and `experiment_policy_states_unique_idx`.

All four plans completed below 0.03 ms execution time in the test database. These checks validate final index selection; production cardinality remains an operational rollout observation.

## Verification

- Scenario YAML validation — passed.
- `mix test test/scenarios/delivery/ab_testing_delivery_runtime_test.exs` — 1 test, 0 failures.
- `mix test test/oli/editing/container_editor_test.exs test/oli/resources/alternatives_test.exs test/oli/delivery/attempts/page_lifecycle_test.exs test/oli/analytics/xapi_test.exs` — 41 tests, 0 failures.
- `mix test test/oli/analytics/xapi/clickhouse_uploader_test.exs test/oli/analytics/xapi/schema_validator_test.exs` — 18 tests, 0 failures.
- `mix compile --warnings-as-errors` — passed.
- `mix test test/oli/experiments test/oli/delivery/experiments test/oli_web/live/workspaces/course_author/experiments_live_test.exs test/scenarios/delivery/ab_testing_delivery_runtime_test.exs` — 161 tests, 0 failures.

## Traceability

- FR-001/002/003: singular definition, condition mapping, UI, configuration, and persistence suites.
- FR-007/009/010: runtime concurrency, repeated-intervention scenario, guardrail, and posterior suites.
- FR-018: configuration history and sequential reuse coverage.
- FR-021: Alternatives fallback/preview and rendering coverage.
- FR-032: flattened LiveView policy-report tests.
- FR-035: PostgreSQL/ClickHouse migration and exact-schema persistence tests.

The scenario continues to use real application modules through `Oli.Scenarios.execute_file/2`; no fixtures, factories, or mocks were introduced into scenario domain setup.
