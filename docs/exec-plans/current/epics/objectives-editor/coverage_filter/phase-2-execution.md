# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/objectives-editor/coverage_filter`
Phase: 2 — Project Settings and Pure Issue Classification

## Scope from plan.md

- Add shared formative and summative coverage thresholds to `ProjectAttributes`.
- Persist them through the existing project update path without a database migration.
- Classify direct coverage and propagate descendant issues through the existing in-memory objective hierarchy.

## Implementation Blocks

- [x] Added defaulted, non-negative formative and summative fields to `ProjectAttributes`.
- [x] Added `ProjectAttributes.coverage_thresholds/1` as the semantic threshold boundary.
- [x] Added the pure `Oli.Authoring.ObjectiveCoverage.Issues` classifier and descendant-to-parent propagation.
- [x] Persisted threshold changes through the existing project context and embedded attributes; no migration or coverage query was introduced.

## Test Blocks

- [x] Added defaults and validation coverage in `test/oli/authoring/course/project_attributes_test.exs`.
- [x] Added direct and rolled-up classification coverage in `test/oli/authoring/objective_coverage/issues_test.exs`.
- [x] Added project persistence and partial-embed preservation coverage in `test/oli/course_test.exs`.
- [x] Phase 2 tests passed as part of the 117-test closeout target on 2026-09-08.

## Work-Item Sync

- [x] PRD, FDD, plan, and requirements proofs were reconciled with the final implementation.
- [x] The Learn more dependency is resolved as a hidden extension point owned by MER-5919.

## Review Loop

- Round 1 findings: Partial updates to `projects.attributes` could discard an already-persisted sibling threshold.
- Round 1 fixes: Added `Course.update_project_attributes/2`, which updates the existing embed and preserves omitted fields.
- Round 2 findings: No remaining Phase 2 security, performance, or data-boundary findings.
- Round 2 fixes: None required.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Final work-item validation passes

## Decision Log

### 2026-09-08 - Preserve sibling project attributes during threshold updates

- Change: Threshold events use a partial embedded-attribute update rather than rebuilding `ProjectAttributes` from only one field.
- Reason: Sequential formative and summative changes must preserve both persisted values and unrelated project attributes.
- Evidence: `lib/oli/authoring/course.ex` and `test/oli/course_test.exs`.
- Impact: Phase 2 persistence is atomic at the embed boundary and backward compatible with existing projects.
