# Phase 8 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling`
Phase: `8 - Add Workflow-Level Scenario Coverage`

## Scope from plan.md

- Prove integrated authoring, publication, delivery, sticky intervention assignment, visible-only completion, scored-page reward, posterior reuse, and decision-point isolation with real Torus infrastructure.
- Keep concurrency, exhaustive boundary, migration, and detailed UI coverage in the targeted tests from earlier phases.

## Implementation Blocks

- [x] Core behavior changes: migrated the existing A/B delivery scenario from the retired single-point request shape to the experiment graph API and expanded it to two independently configured decision points.
- [x] Data or interface changes: no production schema or API changes; scenario hooks use the current public experiment and reward-handoff APIs.
- [x] Access-control or safety checks: author identity and learner delivery scope are server-derived from scenario state; the nonparticipating section and no-experiment fallback remain inert.
- [x] Observability or operational updates when needed: no production observability change was required.

## Test Blocks

- [x] Tests added or updated: the delivery scenario now covers two learners, repeated interventions, distinct sticky assignments, visible-path 100% completion, evaluated scored-page reward, posterior reuse by a later intervention, and isolation from the weighted-random decision point.
- [x] Required verification commands run: scenario schema validation, `mix format`, `mix compile`, targeted scenario runner, `git diff --check`, and work-item validation.
- [x] Results captured: all required commands passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged: no product/design divergence; Phase 8 checklist items were marked complete.
- [x] Open questions added to docs when needed: none.

## Review Loop

- Round 1 findings: security and performance reviewers reported no actionable findings. Elixir review identified missing learner-B assessment coverage, insufficient proof that the later adaptive assignment followed the posterior update, an unscoped accepted-reward count, and an inaccurate page-lookup error.
- Round 1 fixes: added learner B's shared-assessment workflow, tied the later intervention assignment timestamp to the updated policy snapshot, scoped the accepted-reward assertion to learner and attempt, and corrected the lookup error title.
- Round 2 findings (optional): not required.
- Round 2 fixes (optional): not required.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes

## Scenario Infrastructure Decision

The generic DSL already supports authoring, publication, sections, enrollment, learner interaction, and progress assertions, but does not expose experiment graph configuration, intervention assignments, posterior state, or accepted rewards. The established A/B scenario suite already uses real-module hooks for those domain-specific operations. Phase 8 therefore extended those focused hooks rather than adding narrowly coupled global directives. No fixtures, factories, mocks, browser automation, or fixture-backed scenario execution helpers were introduced.
