# MER-5855 LearningObjectiveCoverage Data Source - Product Requirements Document

## 1. Overview

Build a plain application-level Elixir data source for the authoring Learning Objectives Editor. It loads the project's current working-publication projection once and exposes deterministic in-memory coverage, hierarchy, detail, curriculum, and search structures for the editor and its dependent epic features.

## 2. Background & Problem Statement

The current workspace editor assembles attachment counts through an asynchronous LiveView pass and `Publishing.find_attached_objectives/1`. That path does not provide all data needed by the coverage experience, can require additional per-objective or per-content queries, and does not consistently aggregate parent objectives through their Sub-Objectives.

The editor needs a single, compact authoring projection that represents the revisions in the current unpublished working publication. It must support summary counts, page-first detail groups, formative/summative classification, later filtering, and text search without selecting page or activity bodies or parsing page content during interaction. Jira `MER-5855` defines this application-level foundation for the parent epic `MER-5784`; `MER-5794`, `MER-5797`, `MER-5799`, `MER-5800`, and `MER-5801` are consumers or follow-on features.

## 3. Goals & Non-Goals

### Goals

- Provide a focused `LearningObjectiveCoverage` module outside UI code.
- Read the current working publication with one targeted compact projection query scoped to the project.
- Build deterministic objective hierarchy, attachment, page/activity, curriculum, detail, and search indexes in memory.
- Calculate parent and Sub-Objective coverage with the epic's direct-versus-descendant semantics.
- Count static embedded activities through `activity_refs`, without loading full activity or page content.
- Give downstream UI and filter work a stable data contract that does not mutate course content.

### Non-Goals

- Implement the Learning Objectives Editor UI, toolbar, expansion controls, or navigation.
- Implement search/filter UI, CSV export, or project-level threshold persistence.
- Include activity-bank selections or standalone banked activities in initial coverage counts.
- Compute or persist learner proficiency aggregation.
- Introduce a GenServer, supervised cache, external service, schema migration, or database full-text search.
- Repair stale `activity_refs` or parse all page content as a fallback in the interaction path.

## 4. Users & Use Cases

- Authoring workspace: request one project-scoped coverage model and render objective summaries and page/activity details.
- Follow-on filter/search features: query the same normalized model for low-coverage, curriculum, and partial-text filtering without issuing new content queries.
- CSV export: consume compact activity, page, objective, and curriculum metadata without loading full revisions.
- Developers and QA: exercise deterministic pure post-processing independently from LiveView rendering.

## 5. UX / UI Requirements

- No standalone UI is introduced by this work item.
- The data source must provide enough original titles and stable identifiers for consumers to render accessible labels, page-first groups, formative/summative states, and navigation targets.
- The data source must not change the existing authoring content or objective associations while being read.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Performance: use one project-scoped projection over current unpublished publication mappings; do not perform N+1 objective/page/activity queries or select `content` for pages or activities.
- Determinism: normalize and sort relationship collections where consumer rendering or tests depend on ordering; repeated construction from the same projection produces equivalent results.
- Reliability: exclude deleted revisions from coverage and tolerate missing, malformed, or irrelevant optional attributes without crashing the editor.
- Safety: the module is read-only and must not modify revisions, resources, publications, objectives, pages, activities, or associations.
- Maintainability: keep the public API and result shapes focused, document the projection assumptions, and keep data shaping out of the LiveView.
- Security: scope every projection and returned index to the requested project and its current working publication; do not expose data from another project.
- Accessibility/internationalization: preserve source titles and identifiers for consumers; matching normalization must be case-insensitive and whitespace-tolerant without replacing original display text.

## 9. Data, Interfaces & Dependencies

- Add a focused module such as `Oli.Authoring.ObjectiveCoverage` with a constructor/query operation for a project and pure or side-effect-free operations over the resulting model.
- The projection joins the current unpublished publication, published resources, revisions, and project scope, selecting compact fields: revision/resource identifiers, resource type, slug/title, deleted flag, objectives, children, graded flag, activity references, scope, and activity type.
- Partition rows into objectives, pages, activities, and containers, then build objective hierarchy, direct attachments, page-to-embedded-activity relationships, curriculum descendants/paths, coverage summaries, detail groups, and searchable text.
- Page attachment classification uses `graded`; embedded activity classification inherits from its containing page. Activities are deduplicated by objective and assessment bucket for summaries while retaining page-grouped detail identity.
- Parent objective summaries include direct attachments and all associated Sub-Objective attachments; Sub-Objective summaries include only direct Sub-Objective attachments.
- Search text includes objective, Sub-Objective, page, and embedded activity titles and supports normalized partial substring matching in memory.
- Initial activity coverage is static embedded activity coverage only. Bank-selection indexing is a separate follow-up capability.
- Downstream UI work depends on this model; it must not copy the existing delivery `SectionResourceDepot` because authoring uses working-publication revisions.

## 10. Repository & Platform Considerations

- Follow the Phoenix context boundary: domain/data shaping belongs under `lib/oli/` and LiveView orchestration remains under `lib/oli_web/`.
- Respect the resource/revision and publication model: read the revisions referenced by the project's current unpublished working publication, not every historical unpublished revision.
- Avoid older helpers that scan page `content`, including JSON-path parent-page discovery, for this interaction path; use `activity_refs` maintained by page editing.
- Add focused ExUnit tests for query scope, projection partitioning, hierarchy, deduplication, deleted rows, classification, search, and deterministic output. Use scenario coverage only if a real cross-domain authoring workflow is required.
- Verification should include targeted `mix test` and `mix format`; code review should apply security, performance, Elixir, and requirements guidance when implementation is added.
- Jira is the system of record: `MER-5855`, under epic `MER-5784`, is the source ticket for this work item.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item

The module is introduced behind the consuming workspace/editor change and rolls out through the normal deployment process. No database migration or backfill is required for the initial embedded-only model. Existing or stale `activity_refs` data is a follow-up repair/indexing concern.

## 12. Telemetry & Success Metrics

- Use existing telemetry/APM conventions if the consumer path needs operational visibility; useful aggregate signals are projection duration, row counts by resource type, model-build duration, and failures, without logging page/activity bodies.
- Success means one scoped projection supplies all initial coverage, detail, curriculum, and search data for the project, with no repeated per-objective/content queries.
- Functional success is demonstrated by deterministic unit tests and consumer integration tests showing correct parent/Sub-Objective counts, page/activity grouping, filters' source data, search source data, deleted-row exclusion, and read-only behavior.

## 13. Risks & Mitigations

- Large projects make the projection or in-memory model expensive: select only compact attributes, measure query/build duration, and review memory/query shape before integrating into the LiveView.
- Parent and child attachments are double-counted: build MapSet-based relationships and deduplicate resource ids per objective and assessment bucket.
- Deleted or stale revisions appear as coverage: filter deleted revisions at projection time and add regression tests for stale deleted-page/activity rows.
- Activity classification is ambiguous for bank selections: exclude bank selections from the initial model and document deterministic bank coverage as a separate indexed feature.
- `activity_refs` is absent or stale on legacy pages: do not scan full content in the interaction path; track repair/backfill separately and make missing references a defined empty/unknown case.
- A data source accidentally becomes a hidden process or cache: keep it a plain module with explicit inputs and return values, invoked in the parent LiveView process.
- Consumers diverge into separate query paths: document and test the data contract so UI, filtering, and export work reuse the model.

## 14. Open Questions & Assumptions

### Open Questions

- What exact public function names and result structs should be finalized during architecture/design, while keeping the module boundary stable for all consumer tickets?
- Should missing `activity_refs` be represented as an empty relationship or an explicit data-quality marker in the consumer model?
- What stable curriculum path representation do CSV and course-content filtering need beyond descendant page ids?
- Are there existing resource-type constants/helpers that should be used instead of hard-coded identifiers in the projection implementation?

### Assumptions

- The workspace editor is the primary consumer; the older objectives editor route is unchanged unless product explicitly expands scope.
- The working publication contains the revisions needed for objectives, pages, activities, and containers, and `published IS NULL` identifies the authoring working publication.
- Objective attachment data is available in compact revision attributes and embedded activity relationships are available through `activity_refs`.
- Static embedded activities are the only activity coverage counted in this initial ticket.
- Figma details and interaction behavior belong to the consuming UI tickets, especially `MER-5794`.
- Parent proficiency aggregation in `MER-5821` is unrelated to this read-only authoring coverage model and remains out of scope.

## 15. QA Plan

- Automated validation:
  - Run Harness requirements capture, requirements structure validation, and PRD validation.
  - Add targeted ExUnit tests for the compact query scope and selected fields, including no page/activity `content` selection.
  - Test objective hierarchy, direct versus inherited parent counts, page/activity deduplication, formative/summative classification, page-to-activity grouping, curriculum descendants, normalized partial search, deterministic ordering, deleted-row exclusion, and read-only behavior.
  - Run the affected `mix test` targets and `mix format`; run broader tests as implementation risk warrants.
- Manual validation:
  - Inspect representative coverage output for a project containing direct parent attachments, Sub-Objective attachments, duplicate tags, formative/summative pages, embedded activities, containers, and deleted revisions.
  - Confirm the data source does not issue additional content queries or mutate authoring state when invoked by the workspace editor.

## 16. Definition of Done

- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
