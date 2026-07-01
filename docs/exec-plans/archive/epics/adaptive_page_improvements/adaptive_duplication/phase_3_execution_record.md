# Phase 3 Execution Record

## Scope Delivered

Phase 3 completed the adaptive duplication transaction end-to-end:

- duplicated adaptive screen resources are remapped in-place after bulk copy
- duplicated adaptive page resources are created and their deck references are remapped
- duplicated adaptive pages are attached back into the requested container
- curriculum duplication flows now succeed for adaptive pages when the feature flag is enabled

## Implementation Notes

- `lib/oli/authoring/editing/adaptive_duplication.ex`
  - completed `duplicate/3` so the transaction now:
    - bulk duplicates referenced adaptive screens
    - bulk rewrites only changed duplicated screen revisions
    - creates the duplicated adaptive page resource/revision
    - rewrites duplicated page content to the new screen resource ids
    - attaches the duplicated page to the destination container
  - added focused remap helpers for:
    - `authoring.flowchart.paths[*].destinationScreenId`
    - `authoring.activitiesRequiredForEvaluation[*]`
    - nested `activity-reference.activity_id`
    - nested adaptive `idref`
    - nested adaptive iframe `resource_id` / `idref`
  - implemented a single bulk SQL update for heterogeneous revision content rewrites

- Tests updated:
  - `test/oli/authoring/editing/adaptive_duplication_test.exs`
  - `test/oli/editing/container_editor_test.exs`
  - `test/oli_web/live/curriculum/container_test.exs`
  - `test/oli_web/live/workspaces/course_author/curriculum_live_test.exs`

## Verification

- `mix format lib/oli/authoring/editing/adaptive_duplication.ex test/oli/authoring/editing/adaptive_duplication_test.exs test/oli/editing/container_editor_test.exs test/oli_web/live/curriculum/container_test.exs test/oli_web/live/workspaces/course_author/curriculum_live_test.exs`
- `mix test test/oli/authoring/editing/adaptive_duplication_test.exs test/oli/editing/container_editor_test.exs test/oli_web/live/curriculum/container_test.exs test/oli_web/live/workspaces/course_author/curriculum_live_test.exs`

## Follow-Up

- No additional telemetry work was added.
- No work-item doc drift was introduced beyond recording execution outcomes.
