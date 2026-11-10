# Decision Point Manage Link Target

## Classification

- Type: QA finding / targeted enhancement
- Priority: Pre-MVP
- Status: Open
- Release impact: Must be resolved before end-to-end MVP verification

## Finding

The **Select A/B Decision Point** modal includes a **Manage A/B Decision Points** link that still navigates to the legacy Manage Alternatives view:

`/workspaces/course_author/:project_slug/alternatives`

Native A/B decision-point authoring now belongs to the Experiments view, so the link sends authors to the wrong management surface.

## Expected Behavior

- **Manage A/B Decision Points** navigates to the current project's Experiments view:

  `/workspaces/course_author/:project_slug/experiments`

- The project slug is preserved in the generated destination.
- The modal's decision-point selection behavior remains unchanged.

## Acceptance Criteria

- Opening **Select A/B Decision Point** and selecting **Manage A/B Decision Points** navigates to the Experiments view for the current project.
- The link no longer navigates to the legacy Alternatives view.
- Frontend coverage verifies the generated link target.

## Relevant Code

- `assets/src/components/content/add_resource_content/NonActivities.tsx`
- `lib/oli_web/router.ex`
