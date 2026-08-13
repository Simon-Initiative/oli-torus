# Assignment, Rendering, and Completion Slice

## Scope

This slice owns the section relevance gate, page-level batching, intervention-scoped assignment, delivery fallback, preview behavior, rendering, and learner completion consistency in Phase 4.

## Confirmed Phase-Entry Contracts and Baseline

- At Phase 4 entry, `OliWeb.Delivery.Student.LessonLive` called `Oli.Delivery.Experiments.PageDecisions.prepare/2` before rendering.
- No-attempt/no-Alternatives content returned without database work; this was protected by `test/oli/delivery/experiments/page_decisions_test.exs`.
- When any Alternatives placement existed, the phase-entry path batch-resolved group revisions, then performed the one-query `Sections.get_alternatives_render_context/2` lookup. There was no section-level active-experiment relevance query.
- Experiment resolution was recursive and used one database path per distinct `alternatives_id`. The prepared-decision map was keyed by group ID, so repeated placements of one group collapsed to one assignment and one exposure.
- The phase-entry path therefore scaled with distinct experiment-controlled groups and could not satisfy intervention-scoped assignment or the required one-query negative gate without restructuring.

The Phase 4 characterization suite must record SELECT statements (excluding transaction/savepoint noise) for: no Alternatives, irrelevant Alternatives, first active assignment, sticky revisit, 2 and 10 repeated placements, and multiple distinct groups. It must classify queries by touched experiment table and prove runtime code does not query reward history, ClickHouse, or xAPI storage. Target behavior is exactly one indexed relevance query on the negative path; positive-path read counts remain constant as placement count grows except for inserts of missing assignments.

Phase 1 records the current experiment-decision core baseline for both two and ten repeated placements of one group in `test/oli/resources/alternatives_test.exs`: an inactive/no-match group performs 5 SELECTs at either cardinality, while a first active assignment performs 14 SELECTs at either cardinality. Repetition does not increase those counts only because all placements incorrectly collapse to the same group-keyed decision. Full `PageDecisions.prepare/2` adds the already-characterized one-query render-context lookup and batch group-revision resolution; Phase 4 replaces these core counts with the one-query negative gate and placement-aware positive batching.

## Identity Contract

- Fresh placement insertion creates a new wrapper ID and new child IDs.
- Same-page reorder removes and reinserts the same content object, preserving page resource and nested element IDs.
- Whole-page curriculum reorder or movement preserves the page resource and page content, so intervention identity remains stable.
- Basic page duplication creates a new page resource and preserves non-activity element IDs. This satisfies the intervention contract because identity is the tuple of page resource ID and placement element ID. Same-page copy/reinsertion must generate a new placement ID; a future cross-page move obtains identity from its destination page resource and must not copy experiment bindings.
- Whole-project clone currently shares page resources/revisions initially. Project/experiment scoping must prevent a clone from inheriting an active binding unintentionally; this is not treated as a cross-page element move.

Do not regenerate an entire duplicated page's content-element IDs. Same-page Alternatives copy or recreation must generate only the new placement identity needed to avoid collision, preserving `alternatives_id` and unrelated internal element references. In-page reorder and whole-page movement preserve both parts of intervention identity.

## Public API and Prepared Data

`PageDecisions.prepare/2` first asks `Oli.Experiments` whether the section/publication has a relevant active experiment. On a negative result it returns deterministic first-alternative decisions without loading experiment bindings, assignments, policies, rewards, or evidence.

On a positive result, one context API accepts trusted section, publication, enrollment, page resource ID, and all stable valid placement IDs. A single traversal discovers placements inside ordinary containers and stops assignment discovery at each Alternatives boundary, so an Alternatives choice can never reveal another assignment round. The API batch-loads pinned group revisions and normalized group strategies, bulk-materializes missing weighted-random intervention identities, resolves configured Thompson Sampling interventions/bindings, then loads policy snapshots, mappings, and existing assignments. Prepared decisions are keyed by intervention identity, not group ID, and are reused by rendering and completion traversal. Invalid legacy nested placements receive first-branch fallback without assignment or exposure.

## Transaction and Concurrency Ownership

- Assignment identity is `(experiment_id, decision_point_id, intervention_id, enrollment_id)`.
- Sampling reads one committed decision-point policy snapshot. A unique assignment insert is the concurrency arbiter; a losing transaction reloads the winner.
- Assignment counts increment only for the transaction that inserted the row.
- Publication and page revision are evidence context, not sticky identity.

## Fallback and Preview

Missing, inactive, incompatible, or corrupt state renders the first local alternative with bounded telemetry and creates no experiment state. Authoring and instructor preview render all alternatives in keyboard-accessible tabs and never call assignment, exposure, reward, or policy APIs.

## Completion Contract

Rendering and progress/completion consume the same persisted prepared decision. Only descendants of the selected local alternative contribute to numerator or denominator; hidden siblings never do. Shared content and the bound assessment retain ordinary completion behavior.

## Test Targets

- Extend `test/oli/delivery/experiments/page_decisions_test.exs` with the query baseline and target budgets above.
- Extend `test/oli/resources/alternatives_test.exs` and `test/oli/experiments/runtime_test.exs` for repeated-placement identity, sticky revisits, concurrency, deterministic policy seams, and fallback.
- Extend `test/oli/editing/container_editor_test.exs`, add client drop/copy tests, and cover every identity-preserving/regenerating operation explicitly.
- Add rendering and completion matrices with alternatives containing different required-activity counts and exact partial/100% assertions.
- Add accessible inert-preview tests and a scenario-level two-learner completion proof when the scenario DSL can express it.

## Required Indexes and Relevance Query

The negative gate is one `EXISTS` query rooted at `experiment_sections`: join `experiment_definitions` on experiment ID and require the trusted section ID, `state = 'active'`, and a definition project ID in the section's server-derived base/current-remix lineage. It deliberately does not join interventions, assignments, policy state, rewards, or analytics; page-specific work begins only after this gate succeeds.

Support that shape with composite `experiment_sections(section_id, experiment_id)` and a selective active-definition index whose leading key is `project_id` (prefer partial `(project_id, id) WHERE state = 'active'` after verifying enum/DDL compatibility; otherwise `(project_id, state, id)`). Positive-path binding resolution uses `experiment_interventions(page_resource_id, content_element_id)` and joins its decision point/experiment through primary/foreign keys. Assignment uniqueness is indexed by experiment, decision point, intervention, and enrollment. Verify both the negative `EXISTS` plan and the positive binding plan with `EXPLAIN` against representative data before Gate D; reject sequential scans caused by missing/selectivity-poor indexes at expected QA cardinality.

Weighted-random delivery first resolves active participating decision points by the trusted placement's Alternatives Group resource ID, then performs one conflict-safe bulk insert for missing `(decision_point_id, page_resource_id, content_element_id)` rows. Thompson Sampling never takes this path because every adaptive intervention and assessment binding must be validated before activation.

## Decision Log

### 2026-08-13 - Lazily materialize weighted-random placement identity

- Change: The positive delivery batch discovers and persists missing weighted-random intervention rows before assignment resolution.
- Reason: Placement traversal is already the authoritative runtime discovery boundary, and weighted random has no assessment configuration that must precede delivery.
- Evidence: `Oli.Experiments.assign_page_conditions/1` and runtime tests for lazy creation, sticky reuse, and constant batch query shape.
- Impact: Newly placed weighted-random group instances participate without experiment-form synchronization; Thompson Sampling resolution is unchanged.
