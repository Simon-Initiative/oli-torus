# Phase 6 Execution Record

Work item: `docs/exec-plans/current/epics/learning_model_v2/usage`
Phase: `6 - Scenario Coverage, Operational Verification, and Release Gate`

## Scope from plan.md

- Move scenario proficiency assertions to canonical direct and class reads.
- Prove naive and LKT-AOA authoring-to-attempt workflows through non-fixture scenarios.
- Consolidate release verification and document restart, JIT migration, and AppSignal operations.
- Complete security, performance, Elixir, and requirements review gates.

## Implementation Blocks

- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

`ProficiencyAssertion` now resolves objectives from the asserted Section's source project, reads canonical estimates or aggregates, preserves missing-versus-zero semantics, and performs no naive formula reconstruction. The scenario DSL gained a validated `project.learning_model_version` attribute; Section creation continues to inherit the trusted Project model rather than accepting an independent override.

The objective oracle now exposes canonical numeric aggregate coverage/counts, explicitly reports class confidence as unavailable (`nil`), and uses implementation version 4. Numeric oracle values are exercised through summary projection and CSV serialization.

## Scenario Coverage

- `test/scenarios/learning_model/proficiency_usage.scenario.yaml` uses real project authoring, publication, Section creation, enrollment, practice-page visits, evaluated attempts, and student/class proficiency assertions for both persisted models.
- Naive evidence: three correct evaluated activities produce `1.0` / High.
- LKT-AOA evidence: three correct evaluated activities produce `0.65` / Medium under the test configuration.
- The companion runner calls `Oli.Scenarios.execute_file/2` directly. No fixtures, factories, or mocks create scenario domain state.
- The DSL extension is reusable at the Project creation boundary and is wired through type, parser, builder, schema, docs, invalid-input coverage, and Section inheritance coverage.

JIT legacy migration is intentionally proven in the consolidated SectionResource integration tests rather than by mutating persisted migration state inside scenario setup. The scenario exercises normal current projection/depot behavior; `section_resource_migration_test.exs` separately proves first-access legacy migration, lock/version atomicity, rollback, and retry.

## Verification Set

- Scenario schema validation under `MIX_ENV=test` — `schema ok`.
- Companion ExUnit runner — 1 test, 0 failures.
- Scenario infrastructure validation/handler tests — passed; `mix scenarios test/scenarios/learning_model/proficiency_usage.scenario.yaml` created 2 projects and 2 Sections and passed 4 assertions.
- Consolidated proficiency, SectionResource, instructor-dashboard, delivery LiveView, and scenario suite — 2 doctests and 1,478 tests, 0 failures, 9 excluded.
- Focused JIT, telemetry, oracle-version/coverage, numeric projection/export, and scenario set — 47 tests, 0 failures.
- `mix compile --warnings-as-errors` — passed.
- `mix format --check-formatted` — passed after formatting the two reported files.
- `git diff --check` — passed.
- Requirements master validation at `implementation_complete` — FDD, plan, and implementation references verified.
- Full work-item validation (`--check all`) — passed.

## AC-030 Through AC-036 Evidence

- AC-030: Project/Section inheritance tests and the both-model scenario prove persisted selection; LKT-AOA evaluated attempts feed only the LKT-AOA Section.
- AC-031: `rollout.md` requires a restart, rejects a deployment-wide backfill, and describes depot-driven JIT behavior; migration integration tests prove first-access advancement and retry.
- AC-032: `telemetry_test.exs` and the audited telemetry module prove bounded count/categorical metadata without learner, attempt, objective, Section, or content identifiers.
- AC-033: consolidated provider suites cover thresholds, missing versus zero, direct/parent/scoped aggregation, deduplication, and unavailable behavior.
- AC-034: SectionResource migration/projection/depot tests plus oracle version, coverage, summary projection, CSV numeric propagation, cache, and telemetry tests pass.
- AC-035: the non-fixture scenario executes both persisted model workflows through canonical student and class estimates.
- AC-036: SectionResource migration tests prove row locking, in-transaction recheck, atomic marker advancement, rollback, concurrent behavior, and retry.

## Operational Inspection

- Representative naive learner/class results were compared in the scenario at `1.0` / High.
- Representative LKT-AOA learner/class results were inspected at actual numeric `0.65` / Medium; objective-oracle, summary, and CSV tests prove numeric propagation without category reconstruction.
- Legacy-version first access and failure retry are exercised by `section_resource_migration_test.exs`; no fleet-wide backfill exists.
- Provider telemetry metadata was inspected through `telemetry_test.exs` and contains only bounded categorical fields and counts.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed

No PRD/FDD behavior divergence remains. The release runbook was added, Phase 6 plan tasks were completed, and the final traceability record links Gate F evidence.

## Review Loop

- Security: no actionable findings.
- Performance: no Phase 6 findings; the assertion path uses bounded bulk provider reads.
- Elixir: fixed nondeterministic duplicate-title objective lookup by scoping it to `Section.base_project_id`; removed stale page/container documentation.
- Requirements: added explicit objective-oracle confidence/coverage/count fields and version 4; linked legacy JIT evidence separately from the no-fixture scenario; added this Gate F traceability record.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
