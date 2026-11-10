# Phase 4 Execution Record

Work item: `docs/exec-plans/current/epics/objectives-editor/coverage_filter`
Phase: 4 — Settings Popover and Issue Rendering

## Scope from plan.md

- Render project threshold controls and restore-default behavior.
- Render direct and rolled-up issue indications at both hierarchy levels.
- Reconcile light, dark, expanded, collapsed, bucket, page, activity, and responsive states with Figma.

## Implementation Blocks

- [x] Added labelled formative and summative steppers with a zero floor and immediate persistence.
- [x] Added explanatory copy, restore-default behavior, semantic dialog wiring, and click-away dismissal.
- [x] Kept the styled Learn more extension point hidden and non-interactive for MER-5919.
- [x] Added per-bucket warning pills, non-color warning icons, card/row danger borders, and hierarchy-specific formative/summative messages.
- [x] Reconciled objective, sub-objective, page, activity, and bucket icons and sizing with the user-supplied Figma nodes.
- [x] Removed forced no-wrap behavior so warning copy remains within its container at narrow widths.
- [x] Hid the Sub-Objectives summary when its count is zero.

## Test Blocks

- [x] Component tests cover stepper labels/actions, zero-floor state, copy, restore defaults, hidden Learn more, dimensions, and dismissal wiring.
- [x] LiveView tests cover warning markers and messages, healthy-state absence, hierarchy borders, bucket switching, persistence, reclassification, and restore defaults.
- [x] LiveView tests cover the zero Sub-Objectives state and final page/activity icon structure.
- [x] The user completed the final visual comparison against the supplied light/dark Figma states.
- [x] Keyboard semantics and visible focus are covered by native buttons, ARIA assertions, and focus-token assertions.

## Review Loop

- Round 1 findings: Final hand-tuning left stale icon/pointer assertions and an invalid `text-Text-low` utility.
- Round 1 fixes: Removed the invalid utility without changing inherited color and aligned tests with the accepted final geometry.
- Round 2 findings: Learn more documentation and its test still described visible inert text.
- Round 2 fixes: The component documentation and test now require the MER-5919 placeholder to remain hidden and non-interactive.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Human Figma review completed
- [x] Final work-item validation passes

## Decision Log

### 2026-09-08 - Ship Learn more as a hidden MER-5919 extension point

- Change: The final styled text remains in the footer with `hidden` and no link destination.
- Reason: MER-5919 owns the knowledge-base URL and reactivation.
- Evidence: `lib/oli_web/live/workspaces/course_author/objectives/coverage_settings_popover.ex`, its component test, and the user's final instruction.
- Impact: MER-5799 matches the approved release behavior without inventing navigation.
