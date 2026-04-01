# Advanced Gating Scenario Expansion - Delivery Plan

Scope and reference artifacts:
- Source manual cases: `docs/exec-plans/current/epics/automated_testing/gating-tests/tests.md`
- Informal analysis source: scenario-infrastructure gap assessment derived from the manual gating and scheduling cases
- PRD: not present for this work item; this plan is intentionally derived from `tests.md`
- FDD: not present for this work item; this plan is intentionally derived from `tests.md`

## Scope
Expand `Oli.Scenarios` so the advanced gating and scheduling manual cases can be expressed as deterministic YAML-driven integration tests. The work includes first-class scenario support for creating section gating conditions and student exceptions, asserting gate configuration and learner access outcomes, controlling scenario time for schedule-based gating, and simulating the page-start behaviors required by `started` and `finished` gate workflows. The scope includes representative scenario coverage for the documented manual cases and the documentation/schema/runtime changes needed to make the capability durable for future authoring.

## Clarifications & Default Assumptions
- The source of truth for coverage is [tests.md](/Users/darren/dev/oli-torus/docs/exec-plans/current/epics/automated_testing/gating-tests/tests.md), not a PRD/FDD pair.
- The target test layer is `Oli.Scenarios`, not LiveView/browser automation, because the manual cases describe workflow behavior that spans authoring, delivery, enrollment, learner attempts, and gating evaluation.
- First-class scenario directives/assertions are preferred over ad hoc `hook`-based setup so the capability is reusable and discoverable.
- Schedule-gate coverage must be deterministic; relying on wall-clock timing or “relative to now” YAML values is not acceptable.
- Backward compatibility for existing scenario YAML and handlers is required.
- The manual cases map to five capability flows:
  - schedule gate create/verify
  - started gate create/verify
  - finished gate create/verify with minimum score
  - always-open student exception create/verify
  - student-specific exception overriding a parent gate with different semantics

## Phase 1: Confirm Coverage Contract And DSL Boundaries
- Goal: Lock down exactly which manual cases must be expressible and define the minimal reusable scenario surface to support them.
- Tasks:
  - [ ] Translate each manual case in `tests.md` into a scenario-level workflow contract with required setup, action, and assertion points.
  - [ ] Define the first-class directive/assertion set needed for gating support:
    - `gate` directive for top-level gates and student exceptions
    - `assert.gating` assertion for persisted config and effective learner access
    - `time` directive for deterministic clock control
    - `visit_page` directive to generalize page-start simulation beyond practice-only pages
  - [ ] Decide naming, attribute semantics, and validation rules that fit existing `Oli.Scenarios` conventions.
  - [ ] Confirm whether `view_practice_page` remains as a backward-compatible alias or wrapper around `visit_page`.
- Testing Tasks:
  - [ ] Review existing scenario docs, directive types, parser/validator/schema, and gating domain/runtime behavior for compatibility constraints.
  - Command(s): `rg -n "gating|view_practice_page|AssertDirective|DirectiveParser|DirectiveValidator|scenario.schema.json" lib test/support/scenarios test/scenarios priv/schemas -S`
- Definition of Done:
  - Manual cases are mapped to explicit scenario workflows.
  - New scenario capabilities are defined at workflow granularity with no unresolved semantic ambiguities.
- Gate:
  - The planned DSL can express all five manual cases without requiring one-off hooks for core gating behavior.
- Dependencies:
  - Existing gating behavior in `lib/oli/delivery/gating*`
  - Existing scenario architecture in `lib/oli/scenarios/*`
- Parallelizable Work:
  - Gate DSL design and assertion DSL design can be reasoned about in parallel once the manual-case mapping is written.

## Phase 2: Add Core Scenario Infrastructure For Gating And Time
- Goal: Implement the parser, types, engine routing, handlers, and schema updates required to author gating workflows in YAML.
- Tasks:
  - [ ] Add directive structs for `gate`, `time`, and `visit_page` in [directive_types.ex](/Users/darren/dev/oli-torus/lib/oli/scenarios/directive_types.ex).
  - [ ] Extend [directive_parser.ex](/Users/darren/dev/oli-torus/lib/oli/scenarios/directive_parser.ex) and [directive_validator.ex](/Users/darren/dev/oli-torus/lib/oli/scenarios/directive_validator.ex) for the new directives and `assert.gating`.
  - [ ] Extend [engine.ex](/Users/darren/dev/oli-torus/lib/oli/scenarios/engine.ex) to dispatch new directives and preserve any additional execution state needed, including named gates and scenario clock state.
  - [ ] Implement a `gate` handler that:
    - resolves section, target resource, source resource, parent gate, and student references
    - creates gating conditions through `Oli.Delivery.Gating.create_gating_condition/1`
    - updates the section resource gating index after changes
    - stores named gates in scenario state for later exception creation/assertion
  - [ ] Implement a `time` handler that updates scenario-local clock state.
  - [ ] Implement `visit_page` as a generalized learner page-start directive that can cover the “open page” behavior required by started/finished gating flows.
  - [ ] Keep `view_practice_page` backward compatible, either by delegating to the generalized visit behavior or by preserving current behavior alongside the new directive.
  - [ ] Update [scenario.schema.json](/Users/darren/dev/oli-torus/priv/schemas/v0-1-0/scenario.schema.json) so schema validation matches parser/runtime support.
  - [ ] Update any necessary shared runtime/time helper so schedule-gate evaluation can use scenario-controlled time rather than direct `DateTime.utc_now()`.
- Testing Tasks:
  - [ ] Add parser/validator tests for valid and invalid gating/time directive shapes.
  - [ ] Add schema validation tests for new directives and assertion shapes.
  - [ ] Add handler/runtime tests for gate creation, student exception creation, and state bookkeeping.
  - [ ] Add deterministic tests for schedule evaluation under scenario-controlled time.
  - Command(s): `mix test test/scenarios/validation/invalid_attributes_test.exs test/scenarios/validation/schema_validation_test.exs`
- Definition of Done:
  - YAML can declare gates, student exceptions, scenario time, and generalized page visits.
  - Parser, validator, engine, handlers, and schema are fully aligned.
  - Schedule gating is testable without wall-clock dependence.
- Gate:
  - No new directive is parser-only or schema-only; end-to-end runtime support exists for every documented construct.
- Dependencies:
  - Phase 1 DSL decisions
- Parallelizable Work:
  - Parser/schema work can proceed in parallel with handler/runtime implementation if the directive contract is fixed first.

## Phase 3: Add First-Class Gating Assertions
- Goal: Give scenario authors a durable way to assert both gate configuration and learner accessibility outcomes.
- Tasks:
  - [ ] Extend `AssertDirective` support with `gating` assertion data.
  - [ ] Implement `assert.gating` to cover:
    - persisted gate properties by named gate or resolved target/source
    - effective learner accessibility for a resource in a section
    - expected blocking gate types and counts when access is denied
    - exception override behavior for a named learner
  - [ ] Ensure assertions use `Oli.Delivery.Gating.blocked_by/3` and real domain objects rather than UI-layer rendering.
  - [ ] Make assertion messages explicit enough to diagnose wrong gate type, wrong target/source, wrong exception binding, or wrong access result.
- Testing Tasks:
  - [ ] Add focused assertion tests for success and failure paths.
  - [ ] Cover schedule, started, finished, and always-open exception semantics.
  - Command(s): `mix test test/scenarios/directives`
- Definition of Done:
  - Scenario YAML can verify both “gate exists with these semantics” and “student can/cannot access this resource under these conditions.”
- Gate:
  - Manual verification steps in `tests.md` can be translated into scenario assertions without dropping to custom hook code.
- Dependencies:
  - Phase 2 runtime support for gates and time
- Parallelizable Work:
  - Assertion implementation can proceed alongside scenario authoring once handler state and directive shapes are stable.

## Phase 4: Author Representative Gating Scenarios
- Goal: Convert the manual gating cases into focused executable scenario coverage.
- Tasks:
  - [ ] Create a shared setup scenario or reusable YAML fragment for the advanced gating test fixture course, users, enrollments, and page shapes.
  - [ ] Author a schedule-gate scenario covering closed-before-open, open-in-window, and closed-after-end behavior.
  - [ ] Author a started-gate scenario covering blocked access before source-page visit and open access after source-page start.
  - [ ] Author a finished-gate scenario covering blocked access before source completion and open access after graded completion with threshold.
  - [ ] Author an always-open exception scenario covering access for the excepted learner while the base gate remains active for others.
  - [ ] Author an exception-override scenario where the base gate uses one condition and the student exception replaces it with a different condition, matching the documented manual workflow.
  - [ ] Keep scenarios concise and capability-focused rather than reproducing UI click paths.
- Testing Tasks:
  - [ ] Validate each new scenario file structurally.
  - [ ] Run the targeted scenario runner or companion ExUnit modules for the gating scenarios.
  - Command(s): `mix test test/scenarios`
- Definition of Done:
  - All five manual case families have executable scenario coverage.
  - Scenario files are readable, minimal, and reusable as examples for future gating coverage.
- Gate:
  - The authored scenarios fail if the underlying gating behavior regresses in the same ways the manual checks were intended to catch.
- Dependencies:
  - Phases 2 and 3
- Parallelizable Work:
  - Individual scenario YAML files can be authored in parallel once the new directives/assertions are stable.

## Phase 5: Documentation, Discoverability, And Final Validation
- Goal: Make the expanded scenario capability maintainable and easy to use, then validate the work item thoroughly.
- Tasks:
  - [ ] Update [README.md](/Users/darren/dev/oli-torus/test/support/scenarios/README.md) with the new directives/assertions.
  - [ ] Update the relevant scenario docs, especially [sections.md](/Users/darren/dev/oli-torus/test/support/scenarios/docs/sections.md) and [student_simulation.md](/Users/darren/dev/oli-torus/test/support/scenarios/docs/student_simulation.md), or add dedicated gating documentation if that is clearer.
  - [ ] Document YAML examples for:
    - top-level gate creation
    - student exception creation
    - time control
    - access assertions
  - [ ] Verify that existing scenario coverage remains compatible.
  - [ ] Record any follow-up gaps that remain outside this slice, such as broader `progress`-gate coverage if it is not exercised by the current manual cases.
- Testing Tasks:
  - [ ] Run targeted scenario tests and the most relevant gating domain tests together.
  - [ ] Run harness validation commands where applicable, noting that this work item has no `prd.md`/`fdd.md`.
  - Command(s): `mix test test/oli/delivery/gating_test.exs test/scenarios`
  - Command(s): `python3 /Users/darren/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/automated_testing/gating-tests --action verify_plan`
  - Command(s): `python3 /Users/darren/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/automated_testing/gating-tests --action master_validate --stage plan_present`
  - Command(s): `python3 /Users/darren/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/automated_testing/gating-tests --check plan`
- Definition of Done:
  - Scenario infrastructure, examples, docs, and representative gating scenarios are all in place.
  - Validation/test output is captured, with any limitations called out explicitly.
- Gate:
  - A future contributor can author additional gating scenarios using docs and examples without reading the implementation first.
- Dependencies:
  - Phases 1 through 4
- Parallelizable Work:
  - Docs updates can overlap with late-stage scenario authoring once the YAML contract is stable.

## Parallelization Notes
- Phase 1 must complete first to lock the capability contract.
- In Phase 2, parser/schema work and handler/runtime work can proceed in parallel after the directive shapes are fixed.
- In Phase 3 and Phase 4, assertion implementation and representative scenario authoring can overlap if the assertion contract is stabilized early.
- Documentation should start once directive and assertion names are unlikely to change.
- Avoid parallel edits to the same core scenario files (`directive_types.ex`, `directive_parser.ex`, `engine.ex`, `scenario.schema.json`) without clear ownership.

## Phase Gate Summary
- Gate A: The proposed scenario DSL can express all documented advanced gating manual cases without core reliance on custom hooks.
- Gate B: Parser, validator, engine, handlers, and schema remain aligned for every new directive/assertion.
- Gate C: Schedule gating is deterministic under scenario-controlled time.
- Gate D: Representative scenario files cover schedule, started, finished, always-open exception, and override-exception workflows.
- Gate E: Documentation and examples are sufficient for downstream scenario authors to reuse the new capability.
