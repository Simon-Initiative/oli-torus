# Intervention-Scoped Assignment and Assessment-Driven Thompson Sampling - Product Requirements Document

## 1. Overview
Extend native Torus experiments so one experiment governs repeated interventions that share condition identities and policy state. Thompson Sampling assigns each learner independently and stickily at every placed Alternatives instance, and each intervention is paired with a distinct condition-neutral scored page whose first eligible finalized attempt contributes one binary reward to the assigned condition's shared experiment posterior. Weighted random supports either intervention scope or section-and-enrollment scope; new weighted-random experiments default to section-and-enrollment scope.

## 2. Background & Problem Statement
The current native experiment model inserts a decision-point layer between the experiment and the reusable Alternatives Group even though the approved workflow has one group and one policy scope per experiment. Multiple decision points in the current implementation behave as independently optimized sub-experiments rather than coordinated exposure locations. Torus already represents repeated exposure locations as interventions, so it needs separate identities for one experiment-owned group and policy, placed intervention instances, per-instance assignments, and assessment bindings—not an additional N-point policy hierarchy.

## 3. Goals & Non-Goals
### Goals
- Support exactly one reusable experiment-controlled Alternatives Group and one policy/posterior scope per experiment.
- Preserve stable experiment conditions and map them bijectively to stable group alternatives.
- Make every Thompson Sampling placement a separate sticky assignment opportunity while pooling its accepted rewards into the experiment posterior.
- Support weighted-random assignment either per intervention or once per participating section enrollment, and non-contextual Beta-Bernoulli Thompson Sampling only per intervention with assessment-driven binary rewards.
- Preserve existing Alternatives content, normal publication behavior, and learner completion semantics. Preserve experiment history created under the final singular schema; preservation of pre-release QA experiment rows is a non-goal.
- Keep group management contextual: the Alternatives page manages Learner Choice groups, while the Experiments page retains a co-located `Decision Points` section for experiment-controlled groups.
- Make the Alternatives Group the sole authority for selection strategy, assigned implicitly by the management surface where the group is created.
- Allow Alternatives placements inside ordinary content containers while prohibiting any Alternatives placement from containing another Alternatives placement.
- Provide configuration, evidence, telemetry, lifecycle controls, and referential constraints suitable for safe authoring and delivery.

### Non-Goals
- User-wide, institution-wide, project-wide, or cross-section sticky assignment.
- Sharing policy state across experiments.
- Multiple independently optimized decision points, factorial experiments, or coordinated assignment across separate experiments.
- Contextual, hierarchical, factorial, continuous-reward, calibrated-difficulty, or learner-specific bandit models.
- Reusing one assessment binding across interventions, correcting accepted experiment rewards, or guaranteeing allocation percentages.
- Renaming existing `Alt` or `A/B Test` insertion commands, changing section participation, or adding cross-page element movement.
- Migrating, backfilling, or preserving experiment definitions, assignments, rewards, policy state, or experiment analytics created by the pre-release QA-only schema.

## 4. Users & Use Cases
- Authors and learning engineers: define stable conditions, reuse an Alternatives Group across pages, author local content per placement, configure a policy, and bind assessments to interventions.
- Learners: receive potentially different conditions at different interventions, see the same content on revisits, complete a shared assessment, and have completion calculated only from displayed content.
- Researchers: evaluate assignments, exposures, rewards, intervention sequence, assessment context, and posterior changes while accounting for the limits of pooled non-contextual evidence.
- Operators and administrators: detect fallbacks, conflicts, skipped or duplicate rewards, posterior failures, latency, and migration anomalies without exposing learner responses.

## 5. UX / UI Requirements
- Retain the current `Alt` or `A/B Test` insertion terminology and make the selected group strategy immutable after creation.
- Use the standard page content editor as the only editor for placement-local alternative content; experiment configuration must not edit page content or stable alternative identities.
- Keep separate group-management surfaces with consistent shared components and interaction patterns: the Alternatives page lists and creates only `Learner Choice` groups persisted as `user_section_preference`, and the project Experiments page's `Decision Points` section lists and creates only experiment-controlled alternatives persisted canonically as `experiment_controlled`.
- Do not present a group-type selector. The creation surface determines the immutable group strategy, and each surface excludes groups belonging to the other strategy.
- Treat the selected group type as immutable after creation. Page insertion creates an Alternatives instance containing its placement identity, referenced `alternatives_id`, and local alternative content, but no `strategy` field; authoring and delivery resolve strategy solely from the referenced Alternatives Group.
- Offer both `Alt` and `A/B Test` insertion and drag/drop in supported ordinary containers. Hide both insertion choices and reject moves or copied content when the target has an Alternatives ancestor. Existing invalid nesting may be repaired by dragging the inner placement outward.
- Retain group management on both existing routes. Keep the author-facing `Decision Points` label for the experiment-controlled group-management section on the Experiments page, while internal domain names continue to distinguish reusable alternatives groups from experiment policy bindings.
- Use the standard page content editor as the only surface for placement-local alternative content on both group types; neither group-management surface edits page content inline.
- Select one assignment policy when creating the experiment and make it immutable afterward. Authorized authors may configure the experiment's group binding, condition-to-alternative mappings, priors or weights, and guardrails while it is in `draft`. Configure interventions, assessment bindings, and reward thresholds only for Thompson Sampling; weighted-random placements are discovered during delivery.
- Make validation errors identify missing, incompatible, duplicate, or structurally invalid configuration before activation.
- Show all local alternatives in Authoring Preview and Instructor Preview through a basic keyboard-accessible tab interface without invoking assignment or policy behavior.
- Report observed allocations and policy state without presenting probabilistic outcomes as guarantees.
- For every non-draft Thompson Sampling experiment, show each condition's current posterior mean as `Estimated success probability`, calculated as `posterior_alpha / (posterior_alpha + posterior_beta)`, accepted success and failure counts, observed assignment count and share, and the policy state's last-updated time. Provide posterior α and β in an expandable technical view. Clearly distinguish estimated success probability from observed allocation and do not calculate or display next-assignment probability.
- Show the current policy and guardrail status from the same snapshot: normal Thompson Sampling, warm-up weighted random, fixed-control enforcement, or traffic-cap enforcement with affected conditions. Show configured thresholds and current progress where applicable, surface assignment-imbalance monitoring as a warning rather than a selection constraint, and use the experiment lifecycle state to indicate whether assignment is paused or ended.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Assignment creation, assignment reuse, and rendering must remain bounded delivery-path operations and must not scan reward history or analytical stores.
- Delivery for sections without a relevant active experiment must avoid experiment-specific queries and processing after one efficient relevance check, such as a bounded `exists` query or section-level experiment tracking.
- Assignment creation and reward acceptance must be concurrency-safe, atomic where required, retryable, and idempotent.
- Supported writes and database constraints must enforce authorization, project compatibility, binding exclusivity, mapping completeness, and lifecycle immutability.
- Logs, telemetry, xAPI, and ClickHouse evidence must avoid raw learner responses and unnecessary learner identity.
- Preview controls and learner-visible behavior must meet established keyboard and accessibility expectations.
- PostgreSQL and ClickHouse schema changes must use ordinary production-quality migrations with dependency-safe forward and rollback paths. The migrations may discard QA-only experiment operational data rather than transform or preserve it.

## 9. Data, Interfaces & Dependencies
- Experiment owns the assignment policy, one group binding, stable conditions, one bijective condition mapping, policy parameters/state, and many intervention placements.
- An intervention is identified by `(page_resource_id, content_element_id)`; revision and publication identifiers provide delivered-snapshot evidence but do not create a new logical intervention.
- Selection strategy is stored and resolved exclusively from the referenced Alternatives Group. A content element's `strategy` field is legacy, non-authoritative data and must be ignored by authoring, validation, and delivery behavior.
- `priv/schemas/v0-1-0/content-alternatives.schema.json` must describe the completed placement contract: `alternatives_id` is the required group reference, element-level `strategy` is not required or authoritative, and legacy elements that retain a strategy value remain schema-compatible without migration.
- The page-content schema permits Alternatives at any depth in ordinary content but rejects an Alternatives descendant anywhere beneath another Alternatives placement. The rule is structural and does not depend on group strategy metadata.
- Project export must serialize every referenced Alternatives Group with its authoritative strategy, stable option identities and labels, and other required group content. Ingest must recreate the group with that strategy before rewiring every placement to the new resource ID.
- Thompson Sampling assignment uniqueness is scoped by section enrollment, experiment, and intervention instance. Weighted-random uniqueness follows its explicit `assignment_scope`: the same intervention identity or one canonical experiment/section/enrollment identity.
- Thompson Sampling state consists of one Beta posterior per experiment condition, defaulting to `Beta(1, 1)` unless configured otherwise.
- The experiment details page must read the current bounded PostgreSQL policy-state snapshot for posterior display; it must not scan rewards or query xAPI or ClickHouse. Values must be current when the page is loaded or explicitly refreshed, and completed or archived experiments display their frozen final state.
- Each Thompson Sampling intervention has exactly one binding to a distinct scored page and threshold in `[0.0, 1.0]`; weighted random requires no assessment binding.
- Weighted-random delivery recognizes every valid placement of the experiment's Alternatives Group as an intervention and lazily materializes its durable `(experiment_id, page_resource_id, content_element_id)` identity on first encounter. Authors do not register weighted-random interventions.
- Reward identity retains the binding, intervention, experiment, assignment, and source scored-page attempt; compact operational state lives in PostgreSQL and detailed evidence flows through configured xAPI or ClickHouse paths.
- Existing page scoring owns activity weighting, partial credit, manual grading, and normalized overall score calculation.

## 10. Repository & Platform Considerations
- Place experiment rules and persistence in the relevant `lib/oli/` contexts and keep controllers and LiveViews focused on transport and interaction.
- Respect resource/revision and publication immutability: existing Alternatives content remains valid without rewriting or author re-save.
- Use PostgreSQL as the transactional source of truth for assignments, accepted-reward claims, and reduced posterior state; do not query ClickHouse or external xAPI stores in assignment or reward-update paths.
- Use explicit `up/0` and `down/0` Ecto migrations generated with the standard Mix generator and ordinary ClickHouse migrations for affected analytical schemas.
- Keep the versioned Alternatives JSON schema synchronized with the authored and delivered content shape, including validation fixtures or tests for new and legacy placements.
- Preserve Alternatives semantics through project export and ingest: both supported group types and repeated placements must round-trip without deriving strategy from, or requiring strategy on, page content elements.
- Implementation review must apply repository security, performance, Elixir, UI or TypeScript, and requirements lenses as appropriate.
- Jira remains the issue-tracking system of record; ticket writes require a separately reviewed and approved Jira operation.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

Existing Alternatives Groups, placements, revisions, publications, and page content require no content conversion or forced republication. Existing content elements may retain a legacy `strategy` field; the field is ignored rather than migrated, removed, synchronized, or used as a fallback. Existing group revisions with `upgrade_decision_point` remain unchanged and are normalized at read boundaries to canonical `experiment_controlled` behavior. Because the experiment feature is deployed only in QA, the schema collapse may delete or recreate pre-release experiment operational and analytical rows instead of backfilling them. No mixed-version compatibility window or experiment-data preservation is required.

## 12. Telemetry & Success Metrics
- Emit bounded signals for assignment creation and reuse, sampling and selection, deterministic fallback, concurrency resolution, binding resolution, accepted and duplicate rewards, skipped rewards with bounded reasons, posterior updates, evaluation-to-update latency, and migration anomalies.
- Include stable experiment, intervention, condition, algorithm, assessment-binding, publication, and before/after policy context where appropriate.
- Success means Thompson Sampling revisits are stable and separate interventions assign independently; weighted-random behavior follows its configured scope; every accepted Thompson reward updates the correct shared condition posterior exactly once; completion reflects only displayed content; and operators can diagnose failures and latency in AppSignal.

## 13. Risks & Mitigations
- Incorrect attribution could bias every later assignment: use explicit bindings, stable intervention identity, persisted assignments, atomic claims, and idempotency constraints.
- Concurrent encounters or evaluations could duplicate assignments or rewards: enforce database uniqueness and atomic posterior updates, then return the winning persisted result.
- Pooled evidence may be misleading when treatments or assessment success meanings differ by page: document the non-contextual assumption, allow binding-specific thresholds, retain intervention and sequence evidence, and direct unrelated treatments to separate experiments.
- Structural editing could orphan or reinterpret active state: prohibit unsupported active or paused edits and require explicit draft reconciliation before deleting bound entities.
- Separate management surfaces could drift in behavior or implementation: share reusable group-management components and domain operations while keeping their lists, labels, creation actions, and navigation strategy-specific.
- Conflicting group and legacy element strategy values could produce inconsistent behavior: resolve strategy only from the group, stop writing strategy into new placements, and test that legacy element values are ignored.
- Legacy group revisions could stop working after the terminology change: normalize `upgrade_decision_point` and `experiment_controlled` to one internal strategy at every read boundary while emitting only the canonical identifier from new writes.
- Export or ingest could lose the group strategy or miswire repeated placements: serialize the complete group contract, create groups before page rewiring, and verify round trips for both supported types and multiple placements.
- Adaptive delivery could become dependent on analytical history: persist sufficient statistics in PostgreSQL and export detailed evidence asynchronously.
- A posterior percentage without evidence context could imply unjustified certainty or be mistaken for traffic allocation: label it as an estimate, show accepted success and failure counts plus update time, and keep allocation reporting separate.
- Guardrail configuration alone could be mistaken for current enforcement: derive and label the effective policy mode from current policy state and assignment counts, identify affected conditions, and present imbalance thresholds as monitoring warnings rather than assignment behavior.
- Experiment checks could add overhead to every delivery request: gate experiment-specific queries and processing behind an efficient section-level active-experiment relevance check.
- Sensitive learner data could leak into operations: restrict emitted dimensions and exclude raw responses and unnecessary identities.

## 14. Open Questions & Assumptions
### Open Questions
- None.

### Assumptions
- A condition represents the same meaningful instructional treatment across every intervention governed by its experiment.
- Author-selected per-binding thresholds give binary success a sufficiently comparable meaning across pooled assessments; Torus does not statistically calibrate difficulty.
- A learner may contribute multiple correlated observations, and learners who progress farther may contribute more evidence; the MVP does not adjust for those effects.
- Existing scored-page attempt ordering and finalized evaluation state can identify the first eligible reward source deterministically.
- Alternatives may be nested inside ordinary content but never inside another Alternatives placement. Delivery classifies placements with one linear traversal, batches every valid experiment-controlled placement once, and never performs recursive assignment rounds. Invalid legacy nested placements fail closed to their first branch without assignment or exposure and can be repaired manually in authoring; no automated content migration is required.
- Guardrail behavior already defined for native Thompson Sampling remains applicable at experiment scope.
- The Alternatives and Experiments pages remain separate group-management entry points. They should share implementation where practical without combining Learner Choice and Experiment-Controlled groups into one author-facing list.
- `Learner Choice` and `Experiment-Controlled` are author-facing labels for `user_section_preference` and the canonical `experiment_controlled` strategy. The legacy persisted identifier `upgrade_decision_point` is a read-compatible alias for `experiment_controlled` and does not represent a separate algorithm.

## 15. QA Plan
- Automated validation:
  - ExUnit coverage for cardinality and referential constraints, draft-only mutation, binding exclusivity, immutable history, migrations, and authorization.
  - Policy tests for automatic weighted-random intervention discovery and Thompson Sampling assignment per configured instance, posterior snapshot reads, sticky revisits, concurrent first encounters, atomic updates, and deterministic random seams.
  - Reward tests for threshold boundaries, attempt ordering, pending or ineligible attempts, missing assignments, duplicate and concurrent processing, completion freeze, and asynchronous retry behavior.
  - LiveView and frontend tests for configuration validation, local-content ownership, copy or duplicate semantics, lifecycle restrictions, and keyboard-accessible preview tabs.
  - UI tests proving the Alternatives page lists and creates only Learner Choice groups, the Experiments page's `Decision Points` section lists and creates only experiment-controlled groups, both routes remain available, shared interactions stay consistent, and neither surface offers a strategy selector.
  - Authoring and delivery tests proving each creation surface assigns its strategy implicitly, new experiment-controlled revisions write only `experiment_controlled`, legacy `upgrade_decision_point` group revisions remain usable, strategy is immutable and group-owned, new placements do not need an element strategy, and conflicting or absent legacy element strategy values do not affect selection.
  - JSON Schema tests proving the group-reference-only placement shape, required valid `alternatives_id`, and structural compatibility at root and nested locations; resolved-group tests enforce that only non-experiment groups may be nested.
  - Interop round-trip tests for Learner Choice and Experiment-Controlled groups, legacy `upgrade_decision_point` ingest normalization, canonical export, stable option identities and labels, multiple placements of one group, rewritten resource IDs, absent and conflicting legacy element strategy fields, and legacy groups without explicit strategy.
  - `Oli.Scenarios` coverage for authoring multiple placements, publishing, learner assignments across interventions, assessment evaluation, posterior reuse, revisits, and assignment-aware completion.
  - Telemetry and analytics tests for required identities, dispositions, policy values, privacy boundaries, export behavior, and absence of analytical-store reads on delivery paths.
  - LiveView and context tests for non-draft posterior display across conditions, posterior-mean calculation, evidence and assignment counts, observed shares, expandable α and β values, updated timestamps, refresh behavior, algorithm-specific visibility, effective guardrail status, and frozen completed or archived values.
- Manual validation:
  - Configure a weighted-random experiment without interventions, place its group multiple times, configure a multi-intervention Thompson Sampling experiment, and confirm automatic weighted-random discovery plus assignment, revisit, reward, reporting, preview, lifecycle, and completion behavior.
  - Create a Learner Choice group from the Alternatives page and an experiment-controlled group from the Experiments page's `Decision Points` section, verify neither surface mixes types or asks for strategy, and confirm group-management navigation remains contextual.
  - Place each group through its eligible page-editor insertion path and verify placement-local content authoring and runtime selection resolve the group-owned strategy exclusively.
  - Export and ingest a representative project containing both group types and repeated placements, then verify group strategy, options, local placement content, rewired references, and runtime selection semantics in the imported project.
  - Process controlled Thompson Sampling assignments and rewards, load and refresh the experiment details page, and verify each condition's estimated success probability, evidence counts, observed assignment allocation, expandable posterior parameters, current guardrail status, and last-updated time match current PostgreSQL state.
  - Apply and roll back PostgreSQL and ClickHouse schema migrations from the supported pre-release schema state, confirm the final schema shape in both directions, and confirm existing Alternatives content remains usable without conversion. Experiment-row preservation is not asserted.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] Alternatives content schema reflects the final placement contract and compatibility behavior
- [ ] Project export and ingest preserve group-owned Alternatives strategy and placement references
- [ ] Non-draft Thompson Sampling experiments display current, correctly labeled posterior metrics
- [ ] validation passes

## Decision Log

### 2026-08-13 - Treat pre-release QA experiment data as disposable

- Change: Removed migration, backfill, and preservation requirements for experiment operational and analytical rows while retaining PostgreSQL and ClickHouse schema migrations and existing Alternatives content compatibility.
- Reason: The epic is deployed only in QA, so production-style data transformation and mixed-version rollout complexity provides no product value.
- Evidence: Deployment status and explicit product direction for the singular-schema implementation handoff.
- Impact: Schema migrations may reset QA experiment data; tests verify schema correctness and rollback shape rather than historical experiment-row preservation.

### 2026-08-13 - Collapse experiment policy scope to one Alternatives Group

- Change: Replaced multi-decision-point requirements with one experiment-owned group, mapping, policy configuration, posterior scope, and many intervention placements.
- Reason: External platform research found value in multiple exposure locations with stable experiment treatment, but no value in grouping independently assigned sub-experiments. Torus already models exposure locations as interventions.
- Evidence: `design/single_decision_point_analysis.md`, UpGrade developer documentation, LaunchDarkly experimentation documentation, Firebase A/B Testing documentation, and current Torus domain waypointing.
- Impact: Independent tests become separate experiments; implementation must remove the decision-point hierarchy without changing per-intervention sticky assignment or assessment-driven reward behavior.

### 2026-08-13 - Discover weighted-random interventions during delivery

- Change: Weighted-random experiments no longer require authors to configure interventions; every valid delivered placement is discovered and durably materialized on first encounter. Explicit intervention and assessment configuration remains required for Thompson Sampling.
- Reason: Weighted random consumes no rewards, so pre-registering placements adds brittle authoring synchronization without contributing policy configuration.
- Evidence: `lib/oli/experiments.ex`, `lib/oli_web/live/workspaces/course_author/experiment_details_live.ex`, and focused context/runtime/LiveView tests.
- Impact: Weighted-random drafts can activate without intervention rows, new placements participate automatically, and sticky assignments continue to use persisted intervention identity.

### 2026-08-13 - Set assignment policy at experiment scope

- Change: Authors select one immutable assignment policy when creating the experiment rather than selecting or changing policy on decision points or the details page.
- Reason: An experiment represents one assignment strategy and policy scope applied across all of its interventions.
- Evidence: Experiment-details form, `Oli.Experiments` graph validation/persistence, and focused context/LiveView tests.
- Impact: The experiment owns mappings, weights, policy parameters, and intervention bindings; the later schema-collapse phases remove the obsolete decision-point wrapper.
