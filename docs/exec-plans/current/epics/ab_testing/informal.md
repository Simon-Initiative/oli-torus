# Built-in A/B Testing - Informal Source Context

Last updated: 2026-06-11

This document captures initial source context for replacing the external UpGrade dependency with Torus-native A/B testing support. It is intentionally informal source material for later PRD, FDD, requirements, and implementation planning work.

## Decision Context

Torus currently uses the UpGrade framework for A/B testing. Continuing with UpGrade would require a significant cloud infrastructure upgrade and ongoing maintenance burden. The alternative is to build the A/B testing functionality directly into Torus as a separate service within the Torus monolith.

The main decision is not whether Torus can technically replace UpGrade. It can. The real decision is how much UpGrade-like functionality Torus needs to own and in what order.

Torus's current usage of UpGrade is narrow:

- initialize an experiment user using the Torus enrollment id
- assign the enrollment to a condition for an experiment decision point
- mark that the decision point condition was applied
- log correctness metrics after evaluated activity attempts
- export UpGrade-compatible segment and experiment JSON for manual import into UpGrade

UpGrade's full platform is much broader. It includes its own admin UI, backend, experiment lifecycle model, feature flags, segments, group assignment, factorial experiments, stratified sampling, preview users, audit/error logs, metrics querying, SDKs, and adaptive assignment algorithms.

The initial Torus replacement should target the product surface Torus actually uses today while establishing strict domain boundaries, a separate A/B testing service API, and a first-class assignment algorithm boundary. Adaptive assignment algorithms are part of the intended implementation, not just a future parity candidate, but they depend on a reliable assignment, exposure, outcome, and reward-feedback loop owned by the A/B testing service. For migration, Torus should make a reasonable best effort to preserve learner assignments using Torus-local data such as section extrinsic state; a fresh UpGrade assignment import is not required for the MVP, and learners without recoverable local assignment data can be treated as unassigned.

## Current Torus Integration Points

Known local integration paths:

- `lib/oli/delivery/experiments.ex`
  - Runtime HTTP interface to UpGrade.
  - Calls `/api/init`, `/api/assign`, `/api/v1/mark`, and `/api/log`.
  - Uses enrollment id as the UpGrade user id to isolate the same Torus user across sections.
- `lib/oli/resources/alternatives/decision_point_strategy.ex`
  - Selects an alternative by calling `Oli.Delivery.Experiments.enroll/3`.
  - Caches the chosen condition in section extrinsic state via an alternatives preference key.
  - Falls back to the first option when no condition is returned or assignment fails.
- `lib/oli/delivery/experiments/log_worker.ex`
  - Oban worker scheduled after evaluated activity attempts.
  - Computes correctness from activity attempt score/out_of and posts it to UpGrade.
- `lib/oli/delivery/experiments/experiment_builder.ex`
  - Builds UpGrade experiment JSON from Torus alternatives groups.
  - Uses fixed defaults: context `add`, state `enrolling`, individual consistency, individual assignment unit, simple type, equal-ish condition weights, project-slug inclusion segment, and one average correctness query.
- `lib/oli/delivery/experiments/segment_builder.ex`
  - Builds an UpGrade segment JSON using the project slug as a group id.
- `lib/oli_web/controllers/experiment_controller.ex`
  - Provides segment and experiment JSON downloads.
- `lib/oli_web/live/workspaces/course_author/experiments_live.ex`
  - Lets course authors/admins enable A/B testing, create/edit one experiment alternatives group, and download UpGrade import JSON.
- `lib/oli_web/live/experiments/experiments_live.ex`
  - Legacy/non-workspace version of similar experiment authoring UI.
- `lib/oli_web/live/workspaces/course_author/alternatives_live.ex`
  - Still refers to "experiment decision point from Upgrade" when creating decision point alternatives.
- `config/config.exs` and `config/runtime.exs`
  - Configure `:upgrade_experiment_provider` URL, user URL, and API token.
- `priv/repo/migrations/20230302142539_has_experiments.exs`
  - Adds `has_experiments` to projects and sections.

## Current Effective Behavior

The current built-in Torus authoring surface is effectively a simple A/B/N alternatives feature:

- A project can be marked as having experiments.
- Sections inherit `has_experiments` from the project.
- Authors create a decision point as an alternatives resource with strategy `upgrade_decision_point`.
- Decision point options are condition codes by name.
- During delivery, a learner enrollment is assigned to one condition.
- The selected condition determines which alternative content is visible.
- The selected condition is cached in section extrinsic state to avoid repeat UpGrade calls.
- If no active experiment applies, Torus displays the first option and caches that fallback.
- Activity correctness is sent asynchronously to UpGrade as a metric.

Important current limitation: the durable source of assignment truth may be split between UpGrade and Torus extrinsic state. For the initial replacement, Torus-local state should be the practical preservation source. Migration should preserve active learner assignments where Torus has enough local data to do so, and should treat learners with missing or ambiguous local assignment data as unassigned.

## UpGrade Capability Inventory

Source-level review of `CarnegieLearningWeb/UpGrade` shows these relevant capabilities:

- experiment states: draft, scheduled, preview, enrolling/running, enrollment complete/paused, completed, archived
- assignment units: individual, group, within-subjects
- consistency rules: individual, group, experiment
- post-experiment behavior: continue, assign/revert
- weighted random assignment
- stratified random sampling
- factorial experiments with factors, levels, level combinations, and payloads
- condition payloads per decision point
- inclusion and exclusion segments
- global exclusion segments per context
- individual and group enrollment records
- individual and group exclusion records
- repeated enrollment records for within-subject experiments
- monitored decision point exposure records
- metrics/log ingestion
- metric query aggregation
- feature flags
- preview users and preview assignments
- audit and error logs
- import/export of experiment definitions
- client SDK endpoints for init, assign, mark, log, feature flags, aliases, group membership, and working group updates
- Mooclet/Thompson-sampling-style adaptive assignment integration

Not all of this is required to remove the current Torus dependency. These capabilities should be divided into minimum viable replacement, near-term native product features, and later parity candidates.

## Proposed Replacement Direction

Introduce a Torus-native A/B testing service backed by Torus Postgres tables. This should be a separate service inside the monolith, not a set of experiment tables that other Torus contexts read and write directly. A likely namespace is `Oli.Experiments`, with explicit service APIs for delivery, authoring, migration, analytics, and reward/outcome feedback.

The new service should own:

- experiment definition persistence
- decision point and condition configuration
- assignment selection and stickiness
- assignment persistence
- assignment algorithm abstraction
- exposure/mark persistence
- outcome/event logging or outcome association
- reward/outcome feedback for adaptive assignment algorithms
- experiment lifecycle validation
- analytics read models
- migration/backfill from Torus-local assignment state where feasible

Delivery, authoring, analytics, and migration code should call the A/B testing service rather than issuing HTTP requests to UpGrade or reading experiment tables directly. Cross-domain interactions should use service request/response shapes, commands, queries, or events. The service API should use Torus domain language and stable identifiers, not leaked Ecto schemas or table-shaped payloads.

The service boundary should include an anti-corruption layer around current UpGrade-shaped integration points. Existing delivery code can first adapt from `init`, `assign`, `mark`, and `log` semantics into native service calls, but the native service model should not preserve UpGrade endpoint shapes as its internal contract.

## Service API Sketch

Initial service-facing APIs should cover at least:

- delivery assignment
  - resolve active experiment for a section/project and decision point
  - assign or reuse a sticky condition for an enrollment
  - return a condition code and assignment metadata without exposing assignment rows
- exposure recording
  - mark whether a decision point condition was applied, not applied, or unavailable
  - capture page/resource context needed for later analytics
- outcome and reward feedback
  - associate evaluated activity attempts or explicit events with assignments/exposures
  - record reward values needed by adaptive policies
- authoring and lifecycle
  - create and update experiment definitions, conditions, decision points, weights, and lifecycle state
  - enforce validation around edits after assignments exist
- migration/backfill
  - backfill existing Torus-local assignment data, especially section extrinsic state, through service commands
  - preserve assignment provenance such as `extrinsic_state_import`, `native_assignment`, or `fallback`
  - treat learners without recoverable Torus-local assignment data as unassigned
- analytics reads
  - expose read models for assignment, exposure, outcome, and reward reporting
  - avoid requiring analytics code to join against service-owned tables directly

The service boundary is a core product and architecture requirement for the MVP. It should be tested explicitly so later Torus features cannot accidentally couple themselves to A/B testing persistence internals.

## Initial Data Model Sketch

Working tables or schemas owned by the A/B testing service:

- `experiments`
  - project or section scope
  - title, description, state, assignment unit, consistency rule, assignment algorithm, start/end, post-experiment rule, metadata
  - algorithm configuration for adaptive policies where needed
- `experiment_decision_points`
  - experiment id
  - alternatives resource id or revision/resource linkage
  - site/title
  - target
  - order and active flags
- `experiment_conditions`
  - experiment id
  - condition code/name
  - assignment weight
  - order
  - optional payload
- `experiment_assignments`
  - experiment id
  - decision point id
  - section id
  - enrollment id and user id
  - optional group key/id
  - condition id
  - assignment source, inserted_at
- `experiment_exposures`
  - experiment assignment id
  - decision point id
  - status such as applied, not applied, no condition
  - page/resource context
  - timestamp
- `experiment_events`
  - experiment id, assignment id, enrollment/user, event type, metric key, value, metadata
  - May be unnecessary for attempt correctness if analytics can join existing attempt tables to assignments/exposures.
- `experiment_rewards`
  - experiment id, assignment id, condition id, reward value, source event/attempt, metadata
  - Supports adaptive algorithms that update assignment behavior from observed outcomes.
- `experiment_algorithm_states`
  - experiment id, algorithm name/version, serialized policy state, last updated timestamp
  - Needed only for adaptive algorithms that maintain server-side state beyond raw rewards.
- `experiment_segments`
  - inclusion/exclusion definitions
  - Initially could support project/section/cohort/user lists before richer group logic.
- `experiment_audit_logs`
  - author/admin changes to experiment definitions and state.

## Assignment Engine Sketch

For the initial replacement, assignment should be local, transactional, and invoked through the A/B testing service API:

1. Resolve active experiments for the section/project and decision point.
2. Check inclusion/exclusion rules.
3. Reuse an existing assignment for the enrollment when present.
4. If no assignment exists, choose a condition through the configured assignment algorithm.
5. Persist the assignment with enough data for auditability and analytics.
6. Return the condition code and safe assignment metadata to the alternatives strategy.
7. Record an exposure when the decision point content is rendered/applied.
8. Record rewards or outcome signals when the configured algorithm needs feedback.
9. Preserve current fallback behavior when no active experiment applies: show the first option.

The first algorithm should be weighted deterministic random assignment. Its seed should include at least experiment id and enrollment id for individual assignment. Group assignment can later seed by experiment id and group key.

Adaptive algorithms should be implemented behind the same assignment boundary. The service should expose a stable internal behavior such as:

```elixir
assign_condition(experiment, decision_point, subject, context)
record_reward(experiment, assignment, reward, metadata)
```

The implementation can then support weighted random, stratified random, and adaptive policies without delivery code knowing which policy is active or how policy state is stored.

## MVP Scope

The first production slice should replace the current UpGrade dependency without attempting full UpGrade parity.

In scope:

- native simple A/B/N alternatives experiments
- a separate A/B testing service within the Torus monolith
- strict domain boundaries and service APIs for delivery, authoring, migration, analytics, and reward/outcome feedback
- service-owned persistence that other Torus contexts do not query or mutate directly
- an anti-corruption layer from current UpGrade-shaped integration semantics to native service commands and queries
- project-scoped or section-inherited experiments matching current behavior
- individual assignment by enrollment
- weighted random condition assignment
- assignment algorithm abstraction with weighted random as the baseline policy
- adaptive assignment policy support, including the data path for reward/outcome feedback
- sticky persisted assignments
- exposure records
- basic authoring UI updates to remove UpGrade-specific copy and JSON downloads
- correctness/outcome association for evaluated activity attempts
- best-effort migration strategy for active UpGrade-backed experiments using Torus-local assignment data
- tests for service API contracts, boundary enforcement, assignment stickiness, weights, fallback behavior, exposure logging, and section/project gating

Out of scope for the MVP:

- extracting A/B testing into a separately deployed service outside the monolith
- factorial experiments
- stratified random sampling
- within-subject experiments
- feature flags
- full segment builder/import/export parity
- fresh UpGrade assignment import for MVP cutover
- external SDK compatibility
- a full UpGrade-style admin UI

## Follow-On Scope

Near-term native product features after MVP:

- experiment state lifecycle: draft, running, paused, completed, archived
- configurable condition weights in authoring UI
- start/end dates
- preview mode
- adaptive assignment configuration and reward monitoring
- assignment and exposure analytics by condition
- experiment outcome dashboards based on existing attempt data
- audit logs for experiment edits and state changes
- section-level overrides where appropriate
- additional service API hardening for analytics, authoring workflows, and adaptive policy monitoring

Later parity candidates:

- group assignment by section, institution, LMS course/section/group, or custom cohorts
- inclusion/exclusion segments
- multiple decision points per experiment
- post-experiment behavior such as continue or assign fallback condition
- factorial condition/payload model
- stratified random sampling
- within-subject assignment queues
- feature flag use cases
- import/export compatible with UpGrade data for migration or interoperability

## Migration And Cutover Concerns

Active experiments need special handling:

- Determine what active assignment state can be recovered from Torus-local data, especially section extrinsic state.
- Map UpGrade experiment ids/conditions/decision points to Torus alternatives resources and section/project scope.
- Backfill recoverable current assignments into `experiment_assignments` before changing runtime assignment code.
- Preserve existing learner assignments where Torus has enough local data to do so.
- Treat learners without recoverable or trustworthy Torus-local assignment data as unassigned and allow native assignment on next exposure.
- Decide what to do with historical UpGrade logs that do not map cleanly to Torus attempts.
- Support a temporary migration flag if a big-bang cutover is too risky.

The safest runtime migration path is:

1. Add native service-owned tables and service write paths behind a feature flag.
2. Backfill recoverable active assignment state from Torus-local data.
3. Enable native assignment for a pilot project/section.
4. Verify native assignment reuse for learners with backfilled assignments and native assignment for learners without recoverable assignments.
5. Switch all experiment-enabled projects to native assignment.
6. Remove UpGrade configuration and JSON export UI after best-effort local migrations are complete.

## Risks

- Weak service boundaries would recreate the same long-term ownership problem inside the monolith by allowing delivery, authoring, or analytics code to couple directly to experiment tables.
- Learners without recoverable Torus-local assignment data may be assigned natively after cutover, which can affect active experiment continuity for those learners.
- Treating extrinsic state as the practical preservation source may be insufficient for full historical analytics or auditability.
- Full UpGrade parity is a multi-quarter platform project if all advanced capabilities are required.
- Outcome analytics may be misleading unless exposure, assignment, and attempt records are joined with clear timestamps and scopes.
- Adaptive assignment can amplify bad reward signals if outcomes are delayed, sparse, biased, or joined to the wrong exposure.
- Adaptive policy state must be reproducible and auditable enough for research review.
- Group assignment semantics require careful mapping to Torus institutions, sections, LMS groups, products, and enrollments.
- Published content immutability must be respected. Experiment delivery choices should not mutate published revisions.
- Multi-tenancy and institution scoping must be explicit in all reads and writes.
- Service API request and response contracts must be stable enough for delivery, authoring, migration, analytics, and adaptive policy work to proceed independently.

## Open Questions

- What UpGrade features are actually used in production today beyond simple alternatives experiments?
- Are any active experiments using group assignment, segments, factorial designs, stratified sampling, feature flags, or Mooclets?
- What Torus-local assignment data is available for active experiments, and how reliably can it be mapped to native experiment assignments?
- How should missing, ambiguous, or fallback cached assignments be classified during best-effort local migration?
- How many active experiments need best-effort local migration, and can they be paused/completed before cutover?
- What exact API surfaces should the A/B testing service expose for delivery, authoring, migration, analytics, and reward feedback?
- What repository or module boundaries should prevent other Torus contexts from directly accessing A/B testing schemas and tables?
- Should native experiments be authored at project level, section level, or both?
- Should assignment happen at first page render, first decision point render, or first attempt creation?
- Should experiment outcome analytics join existing Torus attempt data or store explicit event metrics?
- Which adaptive assignment algorithms are required for the initial implementation: Thompson sampling, contextual bandits, Mooclet-compatible policies, or a smaller Torus-native policy?
- Should adaptive algorithms be implemented fully inside Torus, integrated through an external policy service, or both behind an adapter?
- What reward signal should drive adaptive assignment: correctness, score delta, completion, time-on-task, later mastery, or configurable metrics?
- How should delayed rewards update algorithm state when an assignment happened much earlier?
- What guardrails are required for adaptive assignment, such as minimum sample sizes, traffic caps, fixed control allocation, or manual pause thresholds?
- What minimum analytics do researchers/instructors need in Torus before UpGrade can be removed?
- Who can create, start, pause, complete, or archive experiments?
- Should experiments be visible to course authors only, administrators only, or instructors in delivered sections?
- Should experiment assignment be deterministic without persistence, persisted only, or deterministic plus persisted?
- What should happen when authors edit condition options after learners have assignments?

## Initial Effort Estimate

Rough implementation phases:

- Phase 1: A/B testing service boundary, native service-owned persistence, delivery assignment API, baseline weighted assignment, and anti-corruption around the current UpGrade-shaped runtime interface, 7-10 weeks.
- Phase 2: Migration, delivery runtime cutover, and UpGrade dependency removal through the service API, 5-7 weeks.
- Phase 3: Authoring/admin lifecycle, basic analytics, and reward/outcome plumbing through service APIs/read models, 6-8 weeks.
- Phase 4: adaptive assignment algorithm implementation and monitoring, plus richer UpGrade-like group assignment, segments, import/export, and audit logs, 9-13 weeks.
- Phase 5: advanced parity such as factorial, stratified sampling, within-subjects, or feature flags, 2-4+ months depending on chosen scope.

These estimates assume existing Torus authoring and delivery patterns are reused through a new A/B testing service API. Treating A/B testing as a separate monolith-internal service adds contract design, API adapters, boundary tests, and review overhead, but it also reduces long-term coupling and leaves a clearer path to future extraction if that ever becomes necessary. Including adaptive assignment increases the importance of outcome/reward modeling, policy-state auditability, and careful rollout controls.
