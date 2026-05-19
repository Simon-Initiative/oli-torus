# Advanced Gating Scenario Coverage Contract

Work item: `docs/exec-plans/current/epics/automated_testing/gating-tests`
Phase: `1 - Confirm Coverage Contract And DSL Boundaries`

Source inputs:
- `docs/exec-plans/current/epics/automated_testing/gating-tests/tests.md`
- `docs/exec-plans/current/epics/automated_testing/gating-tests/plan.md`
- Current advanced gating implementation and current `Oli.Scenarios` capability review

## Purpose
This document converts the manual advanced gating and scheduling matrix into an execution contract for scenario automation. Each manual row is assigned one of two primary dispositions:
- `Scenario after DSL expansion`: should be covered by `Oli.Scenarios`, but current DSL/runtime support is insufficient
- `Retain non-scenario evidence`: should remain covered primarily by existing non-scenario tests because the expected result is UI form behavior, rendering, or browser-only interaction

For this work item, the core behavior rows all belong in scenario coverage once the necessary DSL/runtime support exists. Existing LiveView tests remain useful for UI mechanics, but they are not the primary target evidence for the workflow semantics described in `tests.md`.

## Planned Scenario Files
- `test/scenarios/gating/shared_setup.yaml`
- `test/scenarios/gating/scheduled_gate.scenario.yaml`
- `test/scenarios/gating/started_gate.scenario.yaml`
- `test/scenarios/gating/finished_gate.scenario.yaml`
- `test/scenarios/gating/always_open_exception.scenario.yaml`
- `test/scenarios/gating/exception_override_with_finished.scenario.yaml`
- `test/scenarios/gating/gating_test.exs`

## Missing Scenario Capabilities
- `gate` directive to create:
  - top-level section gates
  - student-specific exceptions attached to parent gates
- `assert.gating` support for:
  - persisted gate configuration
  - learner accessibility on a target resource
  - blocking gate types/counts when access is denied
  - exception override behavior
- deterministic scenario time control for schedule-gate evaluation
- generalized learner page-start support:
  - current `view_practice_page` is practice-only
  - started/finished workflows need a reusable `visit_page` capability that can cover graded sources too
- scenario-local named gate tracking so exceptions and assertions can reference prior gates cleanly

## Manual Case To Scenario Mapping

| Row | Manual case | Disposition | Planned automated evidence |
| --- | --- | --- | --- |
| `GATE ADMIN 1` | Create a `schedule` gate | Scenario after DSL expansion | `scheduled_gate.scenario.yaml` should create a schedule gate and assert its persisted target/type/window semantics |
| `GATE ADMIN 2` | Create a `started` gate | Scenario after DSL expansion | `started_gate.scenario.yaml` should create a started gate and assert target/source wiring |
| `GATE ADMIN 3` | Create a `finished` gate | Scenario after DSL expansion | `finished_gate.scenario.yaml` should create a finished gate with minimum score and assert persisted threshold |
| `GATE ADMIN 4` | Create an `always open` exception | Scenario after DSL expansion | `always_open_exception.scenario.yaml` should create the parent gate plus student-specific `always_open` exception and assert both records |
| `GATE ADMIN 5` | Add a student exception to a started gate using `finished` semantics | Scenario after DSL expansion | `exception_override_with_finished.scenario.yaml` should create the parent `started` gate and override it with a learner-specific `finished` gate |
| `GATE STUDENT 1` | Verify scheduled gate | Scenario after DSL expansion | `scheduled_gate.scenario.yaml` should assert blocked-before-open, accessible-in-window, and blocked-after-end under controlled scenario time |
| `GATE STUDENT 2` | Verify started gate | Scenario after DSL expansion | `started_gate.scenario.yaml` should assert blocked access before source visit and open access after source page is started |
| `GATE STUDENT 3` | Verify finished gate | Scenario after DSL expansion | `finished_gate.scenario.yaml` should assert blocked access before source completion and open access after graded completion at threshold |
| `GATE STUDENT 4` | Verify always open gate | Scenario after DSL expansion | `always_open_exception.scenario.yaml` should assert access for the excepted learner while the base gate remains active for other learners |
| `GATE STUDENT 5` | Verify student exception override lifecycle | Scenario after DSL expansion | `exception_override_with_finished.scenario.yaml` should assert the excepted learner remains blocked after merely starting the source page and becomes unblocked only after finishing it |

## Representative Scenario Set

### 1. `scheduled_gate.scenario.yaml`
Purpose:
- cover top-level schedule gate creation and learner access across time windows

Rows covered:
- `GATE ADMIN 1`
- `GATE STUDENT 1`

### 2. `started_gate.scenario.yaml`
Purpose:
- cover top-level started gate creation and learner unblocking after source-page start

Rows covered:
- `GATE ADMIN 2`
- `GATE STUDENT 2`

### 3. `finished_gate.scenario.yaml`
Purpose:
- cover finished gate creation, persisted minimum score, and learner unblocking after graded completion

Rows covered:
- `GATE ADMIN 3`
- `GATE STUDENT 3`

### 4. `always_open_exception.scenario.yaml`
Purpose:
- cover parent-gate creation plus learner-specific `always_open` override semantics

Rows covered:
- `GATE ADMIN 4`
- `GATE STUDENT 4`

### 5. `exception_override_with_finished.scenario.yaml`
Purpose:
- cover a learner-specific exception that replaces the parent gate semantics with a stricter/different rule

Rows covered:
- `GATE ADMIN 5`
- `GATE STUDENT 5`

## Assertion Strategy

### Assert as domain state in scenarios
- gate existence
- gate type
- gate target resource
- gate source resource where applicable
- schedule window values
- finished minimum percentage
- parent/child exception linkage
- learner accessibility on the target resource
- blocking gate types/counts when access is denied

### Assert as behavior in scenarios
- learner blocked before prerequisite condition is satisfied
- learner unblocked after prerequisite condition is satisfied
- learner-specific exception overrides base gate behavior only for the named learner
- schedule-gated accessibility changes as scenario time moves across the configured window

### Retain as non-scenario evidence
- LiveView form mechanics for gating/scheduling screens
- picker interaction details and flash rendering already covered by existing LiveView tests
- browser navigation details for student delivery pages

## Proposed YAML Shapes

### Gate creation
```yaml
- gate:
    name: "started_gate"
    section: "gating_section"
    target: "Locked Page"
    type: "started"
    source: "Warmup Page"
```

### Schedule gate creation
```yaml
- gate:
    name: "schedule_gate"
    section: "gating_section"
    target: "Locked Page"
    type: "schedule"
    start: "2026-01-10T12:00:00Z"
    end: "2026-01-12T12:00:00Z"
```

### Student exception creation
```yaml
- gate:
    name: "alice_exception"
    section: "gating_section"
    parent: "started_gate"
    student: "alice"
    type: "finished"
    source: "Warmup Page"
```

### Deterministic time control
```yaml
- time:
    at: "2026-01-11T12:00:00Z"
```

### Learner page-start action
```yaml
- visit_page:
    student: "alice"
    section: "gating_section"
    page: "Warmup Quiz"
```

### Gating assertions
```yaml
- assert:
    gating:
      gate: "started_gate"
      type: "started"
      target: "Locked Page"
      source: "Warmup Page"

- assert:
    gating:
      section: "gating_section"
      student: "alice"
      resource: "Locked Page"
      accessible: false
      blocking_types: ["finished"]
```

## Default DSL Decisions
- `gate` is the single directive for both top-level gates and learner exceptions; exceptions are identified by `parent` plus `student`.
- `visit_page` is the generic learner page-start verb; `view_practice_page` should remain backward compatible as an alias or wrapper.
- `assert.gating` should support both named-gate assertions and effective-access assertions.
- Schedule gates must be evaluated using scenario-controlled time, not direct wall-clock calls.
- Scenario authors should refer to resources by title and users by scenario name, consistent with existing DSL patterns.

## Open Constraints
- `lib/oli/delivery/gating/condition_types/schedule.ex` currently uses direct `DateTime.utc_now()`, which prevents deterministic scenario-time control until runtime support is added.
- Current scenario runtime does not store named gates or a scenario-local clock.
- Current student simulation support does not cleanly express “start a graded source page” as a reusable workflow-level directive.
- Existing LiveView gating tests already cover UI concerns; the scenario expansion should not duplicate those tests at the browser-gesture level.
- The work item still lacks `prd.md`, `fdd.md`, and `requirements.yml`, so full harness validation cannot pass until those standard planning inputs exist or the validation contract is adjusted.

## Phase 1 Done Check
- Every manual row has an automation disposition.
- Representative scenario files are named.
- Missing DSL/runtime capabilities are named.
- Domain-state assertions, behavior assertions, and retained non-scenario evidence are explicitly separated.
- Default DSL decisions are locked tightly enough for Phase 2 implementation to start.
