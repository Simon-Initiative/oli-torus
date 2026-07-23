# Online Project Repair Tool - Product Requirements Document

## 1. Overview
The Online Project Repair Tool gives system administrators a safe, project-scoped way to inspect authoring content for two legacy structural problems: Basic pages that share an activity resource and Basic pages that reference an activity resource missing from the project. The tool first presents a read-only preview. After review, an administrator may explicitly repair resolvable shared activities by cloning the shared activity for all but one affected page. Missing activity references are reported only and Adaptive pages are excluded from both analysis and repair.

## 2. Background & Problem Statement
An old, now-fixed page-duplication bug did not always duplicate every activity referenced by the copied page. Some older course projects therefore contain multiple pages that point to the same activity resource, violating Torus's structural requirement that pages not share activity references and creating a risk that work on one page affects another.

Some pages also reference activity resources that no longer resolve in the authoring project. Administrators need visibility into these missing references, but removal is intentionally outside this tool's scope because an absent activity cannot be safely reconstructed and automatically changing the page would be destructive.

The repair surface must be safe to invoke against production-like authoring projects, must not affect published delivery state, and must remain practical for large projects by processing page revision content incrementally rather than retaining all page bodies in memory.

## 3. Goals & Non-Goals
### Goals
- Give system administrators a direct, project-scoped diagnostic and repair surface.
- Separate read-only analysis from an explicit repair action.
- Analyze only Basic pages and completely exclude Adaptive pages identified by top-level `advancedDelivery: true` content.
- Report missing activity references without modifying them.
- Repair shared, resolvable activities using existing authoring duplication and revision APIs.
- Prevent repair attempts when a shared activity resource is missing.
- Keep memory use bounded by streaming or batching revisions and retaining compact identifiers, metadata, and issue summaries.
- Keep domain behavior in a non-web context with a thin LiveView and focused context unit tests.

### Non-Goals
- Removing or otherwise repairing missing activity references.
- Analyzing or repairing Adaptive pages.
- Repairing arbitrary page schema defects beyond the two defined issue types.
- Modifying published publications, delivery sections, or learner state.
- Automatically scheduling repairs or scanning multiple projects.
- Providing a project picker.
- Requiring LiveView tests in the initial implementation.

## 4. Users & Use Cases
- System administrator: navigates directly to a known project's repair route, reviews detected issues, follows page-title links to inspect affected content, and chooses whether to apply shared-activity repairs.
- Developer or support engineer with system-admin access: diagnoses legacy project structure without changing content during analysis and uses structured results to understand any failed repair.
- Course author: indirectly benefits from restored page/activity isolation but is not permitted to access or invoke this administrative tool solely by being a project author.

## 5. UX / UI Requirements
- Expose the LiveView at `/workspaces/course_author/:project_slug/repair_tool`; the route resolves the project from the slug and does not include a project picker.
- On initial load, show a read-only analysis with summary counts, missing activity references, repairable shared activities, and shared missing activity identifiers.
- Render each affected page title as a hyperlink to that page's existing authoring editor route.
- For missing references, show the page identity and missing activity resource id.
- For shared references, group affected pages by activity resource id and show page count, page identities, and whether the activity is repairable.
- Show a clearly labeled `Make Changes` action only when at least one repairable shared activity exists; hide or disable it otherwise.
- After repair, show success counts and the refreshed analysis, or a clear failure result that identifies work that was not completed.
- Ensure links, buttons, status messages, and grouped issue information are keyboard accessible and conveyed with text rather than color alone.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Security: only system administrators may access the route or invoke analysis and repair; all reads and writes remain scoped to the route's selected project.
- Safety: analysis is non-mutating, repair requires an explicit action, missing references are never removed, Adaptive pages are never changed, and activity/page updates use established authoring APIs rather than ad hoc database writes.
- Reliability: repair must use fresh project state, report failures explicitly, and produce a state where rerunning analysis no longer finds the successfully repaired shared relationships.
- Performance: enumerate page revisions through a stream or bounded batches, process one page content payload at a time, and retain only compact relationship maps, page-display metadata, and issue summaries after each page is processed.
- Maintainability: the implementation should be intentionally small and reviewable, reuse existing nested activity-reference extraction and activity-copy behavior, and keep all detection and mutation rules outside `OliWeb`.
- Accessibility: the administrative LiveView must support keyboard operation, visible focus, descriptive links and actions, and semantic presentation of issue groups and statuses.

## 9. Data, Interfaces & Dependencies
- The context should expose project analysis and repair operations, with a working API shape of `analyze_project(project_or_slug, opts \\ [])` and `repair_project(project_or_slug, opts \\ [])`.
- Analysis returns a structured report containing project identity, scan/skip counts, missing-reference records, grouped shared-reference records, repairability, and summary counts.
- Repair returns structured before/after reports plus cloned-activity and updated-page counts, or a structured error suitable for logging and LiveView display.
- Page classification uses the top-level page content key `advancedDelivery`: only boolean `true` is Adaptive; missing or boolean `false` is Basic.
- Missing and repairability checks resolve unpublished project revisions through the project's `AuthoringResolver`.
- Nested `activity-reference` extraction depends on the same established content traversal used by page duplication.
- Shared-activity repair depends on the existing, tested activity duplication/copy implementation and established project revision update mechanisms.
- Page-editor links depend on the existing authoring page-editor route helper.
- Jira is the repository's issue-tracking system of record; no Jira issue key was supplied with this work item.

## 10. Repository & Platform Considerations
- Put analysis and repair behavior in a focused context under `lib/oli/`, with `Oli.Authoring.ProjectRepair` as the working namespace; keep the LiveView under `lib/oli_web/` limited to authorization, orchestration, and rendering.
- Respect the resource/revision and publication model: inspect and update unpublished authoring revisions resolved for the selected project, without changing immutable publication or delivery state.
- Use existing project authorization conventions in the router/live session and enforce system-admin access server-side.
- Use Ecto streaming or bounded pagination in a form compatible with repository transaction and connection constraints; do not preload all revision content.
- Add focused ExUnit context tests using repository test factories and run targeted `mix test` and `mix format` gates.
- Code review must include security and performance reviews plus Elixir, UI, and requirements reviews because this work changes backend domain behavior, authorization, a LiveView surface, and PRD traceability.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

The route is intentionally undiscoverable except by direct project-scoped navigation and is restricted to system administrators. No data migration or automatic invocation occurs at deployment; administrators opt into analysis and each repair manually.

## 12. Telemetry & Success Metrics
- Emit or log a bounded, structured operational result for each analysis and repair invocation, including project identity, pages scanned/skipped, issue counts, clone/update counts, duration, and success or failure, without logging full page content.
- Use existing Phoenix telemetry/logging and AppSignal conventions rather than introducing a product analytics pipeline.
- Success means analysis performs no mutations, Adaptive pages remain untouched, missing references remain report-only, and a post-repair analysis reports zero instances of each successfully repaired shared-activity relationship.
- Context tests covering all required classifications and repair outcomes pass, and manual verification confirms that only system administrators can use the project-scoped workflow.

## 13. Risks & Mitigations
- Risk: an Adaptive page is accidentally included and mutated. Mitigation: centralize the exact top-level `%{"advancedDelivery" => true}` exclusion and cover true, false, and missing-key cases in context tests.
- Risk: stale preview data causes repair of content that changed after analysis. Mitigation: rerun analysis from current authoring revisions immediately before mutation and derive repair work from that fresh result.
- Risk: a missing shared activity is treated as a clone source. Mitigation: require successful `AuthoringResolver` resolution before classifying a shared group as repairable and skip unresolved groups.
- Risk: cloning creates an incomplete activity. Mitigation: call the existing tested activity duplication/copy implementation rather than reproducing copy semantics.
- Risk: a large project exhausts application memory or monopolizes a database connection. Mitigation: stream or batch revision reads, discard full content after extraction, retain only compact maps, and include performance review of query and transaction shape.
- Risk: partial repair leaves an unclear project state. Mitigation: define transaction boundaries explicitly in design, return per-operation failures, and always present a fresh after-analysis when repair completes or partially fails.
- Risk: unauthorized users discover or invoke the route. Mitigation: enforce system-admin authorization in server-side route/session setup and context-facing entry points, not only through hidden navigation.

## 14. Open Questions & Assumptions
### Open Questions
- Should one failed shared-activity group stop the entire repair action, or should independent groups continue with a detailed partial-failure result?
- Which existing helper is canonical for building page-editor links from page resource ids in this authoring route scope?
- Which existing activity-copy and page-revision update APIs should the FDD designate as the supported integration points?
- Which Jira issue should be linked as the execution record for this work item?

### Assumptions
- The persisted Adaptive-page discriminator is the confirmed top-level boolean key `advancedDelivery`; values missing or equal to boolean `false` identify Basic pages.
- The tool operates only on current unpublished authoring revisions returned by `AuthoringResolver` for the selected project.
- Exactly one deterministically selected Basic page, such as the lowest page resource id, may retain the original resolvable shared activity; every other affected Basic page receives a distinct copy.
- Duplicate references to the same activity within one page are represented once in the page-to-activity set and do not by themselves constitute cross-page sharing.
- No new product analytics events or feature flags are needed for this manually invoked, system-admin-only repair surface.

## 15. QA Plan
- Automated validation:
  - Add context tests for a valid project, pages with no references, nested references, duplicate references within one page, missing activities, one and multiple shared groups, and fresh analysis after repair.
  - Test that `advancedDelivery: true` pages are absent from all issue reports and never updated, while missing or false values are treated as Basic.
  - Test that analysis performs no writes and repair leaves missing references unchanged.
  - Test that resolvable shared activities are copied through existing duplication behavior, all but one affected page receive new activity ids, and page revisions contain the updated references.
  - Test that unresolved shared activity ids are reported as missing and are never cloned.
  - Test structured success/error results and project scoping at the context boundary.
  - Run the targeted ExUnit test file and `mix format`; expand to broader authoring tests if integration changes warrant it.
- Manual validation:
  - Verify direct system-admin access and denial for a non-system-admin user.
  - Verify preview counts, grouping, repairability labels, and page-editor links against a prepared project containing each issue type.
  - Confirm initial analysis makes no revision changes and `Make Changes` is unavailable when no repairable shared activity exists.
  - Invoke repair, confirm displayed clone/update counts, and rerun analysis to verify repaired shared issues are gone while missing references remain.
  - Inspect a skipped Adaptive page and published delivery state to confirm neither changed.
  - Inspect operational output in local logs/AppSignal-compatible instrumentation and confirm no full page content is recorded.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
