# Phase 1 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/ui_core`
Phase: `1 - Surface And Data Discovery`

## Scope from plan.md

- Confirm exact implementation boundaries before moving UI and route ownership.
- Trace Activity Bank Selection preview route and legacy renderer.
- Confirm template preview routing assumptions.
- Identify metadata, warning, and sample rendering sources.

## Implementation Blocks

- [x] Core behavior changes
  - No runtime behavior was changed in this phase. Phase 1 was completed as discovery and documentation.
- [x] Data or interface changes
  - No data/interface changes were introduced.
- [x] Access-control or safety checks
  - Current route authorization was mapped for the existing controller route.
- [x] Observability or operational updates when needed
  - No operational changes were needed.

## Discovery Findings

### Current Activity Bank Selection Preview Route

- The existing Activity Bank Selection preview URL is:
  - `/sections/:section_slug/preview/page/:revision_slug/selection/:selection_id`
- The route is currently controller-owned:
  - `lib/oli_web/router.ex`
  - `lib/oli_web/controllers/activity_bank_controller.ex`
- The route runs under the section preview pipeline:
  - `:browser`
  - `:require_section`
  - `:authorize_section_preview`
  - `:delivery_protected`
  - `:delivery_layout`
- The current controller action:
  - authorizes instructor/admin access
  - resolves the page revision from `section_slug` and `revision_slug`
  - finds the selection node by `selection_id`
  - parses the selection logic
  - queries Activity Bank candidates through `Oli.Authoring.Editing.ActivityBank.query_section_publication/6`
  - renders `lib/oli_web/templates/activity_bank/preview.html.heex`

### Legacy Selection Renderer

- `lib/oli/rendering/content/selection.ex` is the current renderer for authored selection blocks.
- It renders the legacy jumbotron-style Activity Bank Selection display.
- It builds the `Preview activities` link using:
  - `/sections/#{section_slug}/preview/page/#{revision_slug}/selection/#{id}`
- Page HTML rendering delegates selection blocks through:
  - `lib/oli/rendering/content.ex`
  - `lib/oli/rendering/content/html.ex`
- `ActivityBankController.preview/2` also calls `Oli.Rendering.Content.Selection.render/3`, but with `include_link? = false`, so the preview page still depends on the legacy renderer for selection metadata display.

### Template Preview Routing

- Template preview launches from product details through:
  - `lib/oli_web/live/workspaces/course_author/products/details_live.ex`
  - `lib/oli_web/controllers/products_controller.ex`
  - `lib/oli/delivery/template_preview.ex`
- `Oli.Delivery.TemplatePreview.prepare_launch/3` only accepts active blueprint sections.
- Product preview stores template preview session state and redirects/logs into:
  - `/sections/#{section_slug}`
- This supports the working assumption that template preview uses the normal section delivery/preview route with a blueprint section slug.
- No separate template-specific Activity Bank Selection preview route was found in this phase.

### Activity Bank Selection Metadata Sources

- Selection id, selected count, and authored selection logic are available directly on the selection content node:
  - `selection["id"]`
  - `selection["count"]`
  - `selection["logic"]`
- Authored criteria display currently comes from `Oli.Rendering.Content.Selection.render/3`.
- Candidate rows and total available count are already queried in `ActivityBankController.preview/2` through `ActivityBank.query_section_publication/6`.
- `Oli.Delivery.InstructorCustomizations.list_bank_selection_candidates/4` also exposes selection review state, candidate titles, and selection enabled state, but currently returns candidate metadata rather than full preview-rendering data.
- Points-per-question does not appear to be stored on the selection node. The existing instructor preview page computes activity points with `Oli.Grading.determine_activity_out_of/1`; the new selection preview should likely derive points from the sample/candidate activity revision or a shared selection-preview context helper.

### Warning Signals

- Scored assessment "students have already started" can be derived from existing `ResourceAttempt` records joined through `ResourceAccess` for the current section and page resource.
- Existing helper references:
  - `Oli.Delivery.Attempts.Core.get_resource_access_for_page/2`
  - `Oli.Delivery.Attempts.Core.get_resource_attempt_history/3`
  - `Oli.Delivery.Attempts.Core.get_graded_attempts_from_access/1`
- A dedicated existence query scoped by `section_id` and `page_resource_id` is still preferable for Phase 5 to avoid loading full attempt/access records.
- Practice page "students have already visited" can be derived from `ResourceAccess` because page visits call `Attempts.track_access/3`.
- `Attempts.track_access/3` creates or increments `resource_accesses.access_count` for `(resource_id, section_id, user_id)`.
- `PageContext.create_for_visit/4` calls `Attempts.track_access/3`, so practice visits are represented in `ResourceAccess`.
- The warning helper in Phase 5 should ignore instructor/template-preview users where appropriate and should not expose learner details.

### Sample Question Rendering Path

- The existing Activity Bank preview page renders candidate activities with authoring elements:
  - `type.authoring_element`
  - `editmode: "false"`
- The newer instructor preview infrastructure renders first-class preview elements when available and falls back to authoring elements otherwise:
  - `lib/oli_web/delivery/instructor/preview_page_context.ex`
  - `lib/oli/rendering/activity/html.ex`
  - `assets/src/components/activities/common/preview/registerPreview.tsx`
- The new Activity Bank Selection UI should reuse that preview/fallback rendering path for the sample question instead of continuing the legacy `activity_bank/preview.html.heex` loop.

## Route And Data Differences Affecting Later Phases

- No separate template Activity Bank Selection route was found.
- The main implementation boundary remains the existing section preview URL, which should be moved or wrapped into LiveView in Phase 2.
- `Oli.Rendering.Content.Selection` may still be needed for authored page rendering outside Instructor Preview; deleting it entirely is not safe until Phase 2/3 trace all remaining authoring/delivery usages.
- Points-per-question remains the only partially unresolved metadata field; it should be resolved while building the selection preview context in Phase 2/3.

## Test Blocks

- [x] Tests added or updated
  - No tests were added. Phase 1 introduced no runtime code or helper functions.
- [x] Required verification commands run
  - `python3 /Users/gastonabella/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/instructor_customizations/ui_core --check all`
- [x] Results captured
  - Initial validation passed before discovery.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
  - No PRD/FDD divergence was found.
  - `plan.md` was updated to mark Phase 1 completed and preserve remaining follow-ups for later phases.
- [x] Open questions added to docs when needed
  - Points-per-question remains open for Phase 2/3 selection context work.

## Review Loop

- Round 1 findings:
  - No formal code review round was run because this phase changed only planning/discovery documentation and introduced no runtime code. This matches `harness-review` guidance for pure document drafting with no behavior diff.
- Round 1 fixes:
  - Not applicable.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled, or skipped by review-skill policy for documentation-only changes
- [x] Validation passes
