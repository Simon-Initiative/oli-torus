# Linked Activities Details From Learning Objectives - Product Requirements Document

## 1. Overview
The Linked Activities page lets an instructor inspect the question-level analytics for activities associated with a selected Learning Objective. It will complete the existing routed page, include activities linked to the selected objective and its sub-objectives, and reuse the expandable detail experience from the Scored Activities and Practice Activities dashboard views.

## 2. Background & Problem Statement
The Learning Objectives dashboard already links to a Linked Activities page, but that page currently provides only a shallow activity table. Instructors cannot inspect question content, answer keys, hints, explanations, dynamic variables, answer distributions, or first-try and eventual correctness without leaving the objective context. The current activity set also excludes activities linked only to child objectives.

The implementation must preserve the published section boundary and use the precomputed `related_activities` data in `SectionResourceDepot`; objective-to-activity discovery must not become an expensive request-time scan of activity revisions.

## 3. Goals & Non-Goals
### Goals
- Complete the existing `RelatedActivitiesLive` route and retain Learning Objectives back-navigation state.
- Display one row for each unique activity resource linked to the selected objective family.
- Include direct links from the selected objective and, for a parent objective, links from effective sub-objectives.
- Reuse the established instructor activity detail rendering and lazy summary-loading behavior.
- Provide activity-level search, Attempts and Score filters, Clear All Filters, and sortable question, attempts, and score columns.
- Preserve correct analytics when linked activities originate on different pages by retaining page context for summary generation.
- Show useful empty states for no linked activities, no filter matches, and activities without question-level analytics.

### Non-Goals
- Changing how activities are tagged with Learning Objectives or how `related_activities` is post-processed.
- Replacing the existing Scored Activities or Practice Activities dashboard views.
- Adding a new route, changing student-facing delivery behavior, or mutating activity revisions, attempts, responses, or analytics summaries.
- Redesigning the underlying analytics model or adding new question-level metrics.
- Supporting activity-bank candidate relationships unless they are already represented in the delivered section resource data.

## 4. Users & Use Cases
- Instructors: select View Activities for a Learning Objective and identify which questions are causing difficulty.
- Instructors: narrow linked activities by attempt volume or score, sort them for comparison, and clear filters to restore the full set.
- Instructors: expand and collapse activity rows to inspect the same question details available in the existing activity dashboard.
- Course administrators: rely on section-scoped, permission-checked analytics without exposing unrelated activities or student data.

## 5. UX / UI Requirements
- Keep the existing page shell, route, selected Learning Objective heading, and Back to Learning Objectives link.
- Render an expandable activity table using the shared activity-table/detail boundary used by Scored Activities and Practice Activities.
- Show exactly three columns per the approved design: question stem/title, `Attempts`, and `% Correct`, each with a sortable header. The `#`/order column and the `Learning Objectives` column used by the selected-page activity table are not displayed on this page, so the shared table model must support hiding them rather than being forked.
- Provide Search, Attempts, Score, and Clear All Filters controls with the same parameter semantics and labels as selected-page activity mode.
- Expanded details must include Question, Answer Key, Hints, Explanation, Dynamic Variables when applicable, answer distribution, First Try Correct, and Eventually Correct.
- All rows render collapsed on initial load; expansion is always instructor-initiated.
- Lazy loading must show the existing loading state, and an activity with no question-level analytics must show the established empty message rather than failing or displaying stale details.
- Preserve keyboard-accessible expansion controls, filter controls, sortable headers, pagination, and visible focus states.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Authorization: all objective, activity, page, learner, and analytics reads remain scoped to the current instructor-accessible section and institution.
- Privacy: the page must not expose raw student responses or PII beyond the existing aggregate dashboard presentation, and logs/telemetry must use bounded counts and identifiers appropriate for operations.
- Performance: derive the linked ID set from depot-backed section resources with batch lookups and de-duplication; do not scan activity revision objectives in the request path or introduce per-activity discovery queries.
- Reliability: missing summaries, stale section-resource relationships, unavailable page context, and zero-attempt activities must produce deterministic loading or empty states without crashing the LiveView.
- Accessibility: all interaction controls remain keyboard operable, have meaningful accessible names and states, and preserve focus behavior when rows expand or filters change.
- Compatibility: existing Scored Activities, Practice Activities, Surveys, and unrelated Learning Objectives behavior remain unchanged.

## 9. Data, Interfaces & Dependencies
- Extend or reuse `OliWeb.Delivery.Pages.ActivitiesTableModel` and `OliWeb.Delivery.ActivityHelpers` through a shared activity list/detail boundary rather than duplicating question-detail rendering.
- `ActivitiesTableModel` currently defines `#`, `Question Stem`, `Learning Objectives`, `Attempts`, and `% Correct`. It needs a column-visibility mode so the Linked Activities page renders only `Question Stem`, `Attempts`, and `% Correct` while Scored and Practice Activities keep all five columns unchanged.
- `RelatedActivitiesLive` resolves the selected objective and effective child objective resources through `SectionResourceDepot`, unions their `related_activities` arrays, and passes unique activity rows to the shared boundary.
- Linked rows retain activity revision data plus a containing page revision/context required by `ActivityHelpers.summarize_activity_performance/6`.
- When an activity occurs on multiple pages, the default product behavior is one row per unique resource ID with aggregate attempts/correctness across the in-scope occurrences; question presentation comes from the published activity revision used by the canonical summary context.
- Reuse existing filter and navigation parameters: `text_search`, `selected_attempts_ids`, `avg_score_percentage`, `avg_score_selector`, `sort_by`, `sort_order`, `offset`, and `limit`.

## 10. Repository & Platform Considerations
- Keep route and interaction concerns in `lib/oli_web/live/delivery/instructor_dashboard/learning_objectives/related_activities_live.ex`; keep section/resource and analytics rules in the relevant `lib/oli/` contexts.
- Use the publication and delivery model: resolve data from the current section's published resources, never mutable authoring state.
- Prefer `SectionResourceDepot` and existing post-processing output over new request-time database traversal.
- Update or retire `lib/oli_web/components/delivery/learning_objectives/related_activities_table_model.ex` only as needed to make it a thin adapter to the shared renderer.
- Revise the existing related-activities LiveView tests and add focused unit coverage for objective-family ID derivation and aggregation semantics.
- Code review must include security, performance, Elixir/Phoenix, UI/accessibility, and requirements-traceability lenses; implementation tracking remains in Jira per repository policy.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

The change is additive to an existing instructor route. Existing activity and analytics data require no migration. Deployment can use the normal release process, with regression monitoring focused on the Learning Objectives dashboard and the existing activity dashboard tabs.

## 12. Telemetry & Success Metrics
- Product success: instructors can inspect required question-level detail from the Learning Objective workflow without navigating to another dashboard.
- Product success: parent objective views include direct and sub-objective-linked activities exactly once, while child objective views remain scoped to that child.
- Operational metrics: linked-activity load latency, summary-load latency, row counts, cache hit/miss outcomes, empty-summary counts, and errors, without raw responses, PII, or authored content.
- Regression signal: no material increase in request-time database queries, LiveView errors, or latency compared with the existing linked-activities page.

## 13. Risks & Mitigations
- Risk: activity summary APIs require page context while objective links span pages. Mitigation: build an activity-to-page context map, group summary work by page, and define unique-row aggregation explicitly.
- Risk: parent and child arrays contain duplicate activity IDs. Mitigation: union and de-duplicate IDs before row construction and test duplicate placement.
- Risk: copying `Pages` state creates divergent behavior. Mitigation: extract the generic expansion, cache, lazy loading, and adaptive-summary repair boundary and reuse the existing table model.
- Risk: broad depot traversal or per-row queries regress dashboard performance. Mitigation: use depot batch APIs, bounded page-context discovery, and telemetry for query/latency regressions.
- Risk: stale or absent analytics make expansion appear broken. Mitigation: preserve loading and no-attempt empty states from the existing activity details path.

## 14. Open Questions & Assumptions
### Open Questions
- None open. Prior questions about initial row expansion and route naming are resolved in Assumptions below.

### Assumptions
- The existing route and Back to Learning Objectives parameter preservation are the supported navigation contract.
- All rows start collapsed on initial load. No activity auto-expands, which intentionally differs from the current Practice Activities behavior. Captured in AC-020.
- The route path stays `.../learning_objectives/related_activities/:resource_id`. The engineering direction on the ticket is to build out the existing route rather than introduce a second URL, and adding a new route is already a stated non-goal. Visible page copy uses the product term Linked Activities.
- A parent objective includes its effective descendant objective resources; a selected child includes only that child unless future product scope changes.
- One row per unique activity resource, with aggregate attempts and correctness across accessible in-scope page occurrences, is the implemented behavior captured in AC-006. It follows the ticket wording "unique set of resource ids". A future occurrence-level requirement would require revising AC-006 and the aggregation semantics.
- The approved design shows only `Question Stem`, `Attempts`, and `% Correct`, so the `#` and `Learning Objectives` columns are intentionally hidden on this page.
- `related_activities` post-processing is populated for the delivered section and remains the source of truth for objective-linked activity IDs.
- Existing activity detail components define the approved wording, formatting, and empty states for question analytics.

## 15. QA Plan
- Automated validation:
  - Extend `test/oli_web/live/delivery/instructor_dashboard/learning_objectives/related_activities_live_test.exs` for route navigation, parent/child scope, de-duplication, unrelated exclusion, search, filters, clear, sorting, expansion, collapse/re-expansion, and empty states.
  - Add focused unit coverage for deriving and de-duplicating the objective-family activity ID set.
  - Verify detail output against the shared Scored Activities/Practice Activities rendering path and verify no mutation of revisions, attempts, responses, or summary records.
  - Run targeted ExUnit tests, formatting, and the repository PRD/requirements validators.
- Manual validation:
  - Verify instructor navigation, filter/sort interactions, expansion loading, empty states, keyboard behavior, and responsive layout in a section with parent, child, duplicate, unrelated, and zero-attempt activities.
  - Compare required detail sections and labels with Scored Activities and Practice Activities.
- Automated implementation evidence:
  - `test/scenarios/linked_activities/linked_activities.scenario.yaml` exercises real authoring, publication, delivery, enrollment, attempts, parent/child scope, duplicate placement, unrelated activities, and cross-page aggregation.
  - `test/oli_web/live/delivery/instructor_dashboard/learning_objectives/related_activities_live_test.exs` and the shared table tests cover route behavior, controls, expansion state, sorting, pagination, empty states, and accessibility attributes.

## 16. Definition of Done
- [x] PRD sections complete
- [x] requirements.yml captured and valid
- [x] validation passes

## Decision Log

### 2026-09-05 - Reconcile Implemented Linked Activity Semantics
- Change: Updated AC-006 assumptions and QA evidence to describe the implemented unique-row, cross-page aggregation behavior.
- Reason: The resolver, LiveView integration, and real scenario coverage now exercise this behavior end to end.
- Evidence: `lib/oli/delivery/sections/linked_activities.ex`, `test/scenarios/linked_activities/linked_activities.scenario.yaml`, and phase 3-6 execution records.
- Impact: Product documentation now distinguishes implemented behavior from future occurrence-level alternatives; manual visual QA remains a separate open gate.
