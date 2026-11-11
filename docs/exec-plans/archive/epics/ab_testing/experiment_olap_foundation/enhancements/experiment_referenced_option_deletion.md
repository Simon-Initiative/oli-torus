# Experiment-Referenced Option Deletion

## Classification

- Type: QA finding / targeted enhancement
- Priority: Pre-MVP
- Status: Open
- Release impact: Must be resolved before end-to-end MVP verification

## Finding

Manage Alternatives currently allows an option to be deleted without accounting for references from draft, active, paused, completed, or archived experiments. Destructive deletion could invalidate experiment condition mappings or historical learner-assignment evidence.

Existing behavior already covers the adjacent lifecycle cases:

- Renaming preserves the stable option ID and therefore preserves experiment references.
- Authored page content belonging to a deleted option is retained as flagged stale content rather than reassigned.

This enhancement is limited to deletion integrity; it is not a new epic feature lane or a redesign of alternatives authoring.

## Expected Behavior

- An option referenced by an experiment cannot be deleted in a way that invalidates condition mappings or historical assignments.
- Manage Alternatives presents actionable feedback when deletion is rejected.
- A rejected deletion leaves option order, authored content, experiment conditions, and learner assignments unchanged.
- The rule is enforced through an approved domain boundary rather than by directly coupling the authoring UI to experiment persistence.

## Decisions Required

- Whether a draft-only reference may be removed transactionally through an explicit experiment edit, or deletion remains blocked while any reference exists.
- Whether an option referenced by a completed or archived experiment may ever be deleted.

Until those decisions are made, the safe default is to block deletion whenever an experiment reference exists.

## Acceptance Criteria

- Deletion attempts are covered for references from draft, active, paused, completed, and archived experiments.
- References from active or historical experiments cannot be silently orphaned.
- Rejected deletion returns an actionable error to Manage Alternatives.
- Tests verify that rejected deletion causes no partial mutation.
- Existing stable rename and stale authored-content behavior remains unchanged.

## Relevant Code

- `lib/oli_web/live/workspaces/course_author/alternatives_live.ex`
- `assets/src/components/resource/editors/AlternativesEditor.tsx`
- `lib/oli/experiments.ex`

