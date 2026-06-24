# Built-in A/B Testing - Informal Source Context

Last updated: 2026-06-22

This document captures initial source context for moving away from the external UpGrade dependency with Torus-native A/B testing support. It is intentionally informal source material for later PRD, FDD, requirements, and implementation planning work.

## Decision Context

Torus currently uses the UpGrade framework for A/B testing. Continuing with UpGrade would require a significant cloud infrastructure upgrade and ongoing maintenance burden. The alternative is to build the A/B testing functionality directly into Torus as a separate service within the Torus monolith.

The main decision is not whether Torus can technically replace UpGrade. It can. The real decision is how much native experiment functionality Torus needs to own and in what order.

Torus's current usage of UpGrade is narrow:

- initialize an experiment user using the Torus enrollment id
- assign the enrollment to a condition for an experiment decision point
- mark that the decision point condition was applied
- log correctness metrics after evaluated activity attempts
- export UpGrade-compatible segment and experiment JSON for manual import into UpGrade

UpGrade's full platform is much broader. It includes its own admin UI, backend, experiment lifecycle model, feature flags, segments, group assignment, factorial experiments, stratified sampling, preview users, audit/error logs, metrics querying, SDKs, and adaptive assignment algorithms.

The initial Torus replacement should target the product surface Torus actually uses today while establishing strict domain boundaries, a separate A/B testing service API, and a first-class assignment algorithm boundary. Adaptive assignment is now MVP scope, and the required first adaptive algorithm is Thompson Sampling for binary reward outcomes, using the Beta-Bernoulli model described in `docs/exec-plans/current/epics/ab_testing/references/EASI_ThompsonSampling.ipynb`. Weighted deterministic random assignment can remain the baseline non-adaptive policy, but the MVP architecture must be capable of running Thompson Sampling natively. Torus will make a hard cut-over from UpGrade to the native A/B testing service. Existing and in-progress UpGrade-based experiments will not be migrated; native A/B testing should be treated as a new feature, and all learners should be treated as new participants in native experiments.

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

Important current constraint: existing and in-progress UpGrade-backed experiments are not migrated into native experiment records. Native A/B testing starts fresh: new native experiments are authored in Torus, native assignments start from the native service, and all learners are considered new participants for native experiments.

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

Current Torus production usage should be treated as simple alternatives experiments only. Group assignment, segments, factorial designs, stratified sampling, feature flags, and Mooclet-style adaptive assignment are not assumed to be active production requirements for the native MVP.

## Adaptive A/B Testing Guidance

New MVP guidance requires native support for adaptive A/B testing, with Thompson Sampling as the main adaptive algorithm. This should be treated as a first-class MVP feature, not only as future UpGrade parity.

The included notebook, `docs/exec-plans/current/epics/ab_testing/references/EASI_ThompsonSampling.ipynb`, models the initial policy as a binary-reward multi-armed bandit:

- each experiment condition is an arm
- each arm starts with a Beta prior, initially Beta(1,1) unless configured otherwise
- assignment samples one candidate success probability from each condition's current Beta posterior
- the condition with the highest sampled value is selected
- when a reward is observed for the selected condition, the selected condition's posterior is updated
- binary success increments the alpha/success count; binary failure increments the beta/failure count
- early traffic is exploratory because condition posteriors are uncertain
- later traffic shifts toward conditions with stronger observed reward evidence while still allowing occasional exploration

External research references align with this model. Agrawal and Goyal's analysis of Thompson Sampling for multi-armed bandits describes the Beta prior/posterior update for Bernoulli rewards, and Russo et al.'s tutorial frames Thompson Sampling as posterior sampling for sequential decisions that balance exploration with exploitation.

Research references:

- `docs/exec-plans/current/epics/ab_testing/references/EASI_ThompsonSampling.ipynb`
- Agrawal and Goyal, "Analysis of Thompson Sampling for the Multi-armed Bandit Problem": https://proceedings.mlr.press/v23/agrawal12/agrawal12.pdf
- Russo, Van Roy, Kazerouni, Osband, and Wen, "A Tutorial on Thompson Sampling": https://web.stanford.edu/~bvr/pubs/TS_Tutorial.pdf

MVP Thompson Sampling constraints:

- Initial adaptive scope should be non-contextual Thompson Sampling over experiment conditions.
- The reward model should begin with binary rewards in `[0, 1]`, matching correctness or another explicitly configured success/failure signal.
- The service must persist per-condition posterior parameters, at minimum alpha/success and beta/failure counts, with algorithm name/version and update timestamps.
- Assignment must be sticky for an enrollment once assigned, even when the global posterior changes later.
- Reward updates must be idempotent so retried Oban jobs or repeated outcome associations do not double-count successes or failures.
- Reward updates must be traceable to a source event or attempt so researchers can audit why a posterior changed.
- Delayed and missing rewards must be expected; assignment cannot assume immediate feedback.
- Adaptive assignment should have guardrails such as minimum sample sizes or warm-up traffic, optional fixed control allocation, traffic caps, manual pause, and monitoring for missing rewards or extreme assignment imbalance.
- Contextual Thompson Sampling, continuous rewards, batch/parallel policy updates, and richer prior configuration are follow-on capabilities unless separately required.

Not all UpGrade capabilities are required to remove the current Torus dependency. These capabilities should be divided into minimum viable replacement, near-term native product features, and later parity candidates.

## Proposed Replacement Direction

Introduce a Torus-native A/B testing service backed by Torus Postgres tables. This should be a separate service inside the monolith, not a set of experiment tables that other Torus contexts read and write directly. A likely namespace is `Oli.Experiments`, with explicit service APIs for delivery, authoring, analytics, and reward/outcome feedback.

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

Delivery, authoring, and analytics code should call the A/B testing service rather than reading experiment tables directly. Cross-domain interactions should use service request/response shapes, commands, queries, or events. The service API should use Torus domain language and stable identifiers, not leaked Ecto schemas or table-shaped payloads.

The service boundary should include an anti-corruption layer around current UpGrade-shaped integration points during removal. Existing UpGrade endpoint shapes should not become the native service's internal contract.

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
  - For Thompson Sampling, should store per-condition posterior parameters such as alpha/success and beta/failure counts, prior configuration, algorithm version, and enough update metadata to make state changes reproducible.
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

The first non-adaptive algorithm should be weighted deterministic random assignment. Its seed should include at least experiment id and enrollment id for individual assignment. Group assignment can later seed by experiment id and group key.

The first adaptive algorithm must be non-contextual Thompson Sampling with a Beta-Bernoulli reward model. At assignment time, the algorithm should sample from each condition's Beta posterior and choose the condition with the highest sampled value. At reward time, the algorithm should update only the posterior for the assigned condition based on the observed binary reward. The implementation should make the random draw auditable enough for debugging, without requiring delivery code to know how posterior sampling works.

Adaptive algorithms should be implemented behind the same assignment boundary. The service should expose a stable internal behavior such as:

```elixir
assign_condition(experiment, decision_point, subject, context)
record_reward(experiment, assignment, reward, metadata)
```

The implementation can then support weighted random, Thompson Sampling, stratified random, and later adaptive policies without delivery code knowing which policy is active or how policy state is stored.

## MVP Scope

The first production slice should cut over from UpGrade to native A/B testing without leaving an ongoing UpGrade runtime path or migrating existing UpGrade experiments.

In scope:

- native simple A/B/N alternatives experiments
- a separate A/B testing service within the Torus monolith
- strict domain boundaries and service APIs for delivery, authoring, analytics, and reward/outcome feedback
- service-owned persistence that other Torus contexts do not query or mutate directly
- an anti-corruption layer from current UpGrade-shaped integration semantics into native service commands and queries
- project-scoped or section-inherited experiments matching current behavior
- individual assignment by enrollment
- weighted random condition assignment
- assignment algorithm abstraction with weighted random as the baseline non-adaptive policy
- Thompson Sampling as the MVP adaptive policy, initially using a Beta-Bernoulli binary reward model
- reward/outcome feedback, policy-state persistence, idempotent posterior updates, and adaptive monitoring needed for Thompson Sampling
- sticky persisted assignments
- exposure records
- basic authoring UI updates to remove UpGrade-specific copy and JSON downloads
- correctness/outcome association for evaluated activity attempts
- native-only authoring and assignment for new experiments
- all learners treated as new participants for native experiments
- tests for service API contracts, boundary enforcement, assignment stickiness, weights, fallback behavior, exposure logging, and section/project gating

Out of scope for the MVP:

- extracting A/B testing into a separately deployed service outside the monolith
- factorial experiments
- stratified random sampling
- within-subject experiments
- feature flags
- full segment builder/import/export parity
- any migration of existing or in-progress UpGrade-based experiments
- any preservation or import of UpGrade learner assignments
- historical UpGrade analytics import
- external SDK compatibility
- a full UpGrade-style admin UI

## Follow-On Scope

Near-term native product features after MVP:

- experiment state lifecycle: draft, running, paused, completed, archived
- configurable condition weights in authoring UI
- start/end dates
- preview mode
- richer adaptive assignment configuration and reward monitoring beyond the MVP Thompson Sampling controls
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

## Cutover Concerns

Cutover should be handled as a clean transition to a new native feature:

- New experiments should be created, assigned, exposed, rewarded, and analyzed through the native A/B testing service.
- The authoring surface should stop creating new UpGrade-backed experiment definitions and should remove the JSON export/import workflow.
- Existing and in-progress UpGrade-based experiments should not be migrated into native experiment records.
- Existing UpGrade learner assignments should not be imported or preserved.
- All learners should be considered new participants when they enter a native experiment.
- Historical UpGrade logs should not be imported into native experiment analytics.
- Cut-over should remove the active dependency on UpGrade runtime assignment, mark, and log calls.

The safest runtime transition path is:

1. Add native service-owned tables and service write paths behind controlled rollout.
2. Disable new UpGrade-backed authoring and route new experiments to native authoring.
3. Enable native assignment, exposure, reward, analytics, and Thompson Sampling behavior for native experiments.
4. Remove UpGrade configuration, JSON export UI, and runtime assignment/mark/log calls as part of the hard cut-over.

## Risks

- Weak service boundaries would recreate the same long-term ownership problem inside the monolith by allowing delivery, authoring, or analytics code to couple directly to experiment tables.
- Existing UpGrade experiments will not continue natively, so teams running in-progress experiments need product communication and closure guidance before cut-over.
- Treating native A/B testing as a new feature means there is no historical continuity for UpGrade assignment, exposure, reward, or analytics data.
- Full UpGrade parity is a multi-quarter platform project if all advanced capabilities are required.
- Outcome analytics may be misleading unless exposure, assignment, and attempt records are joined with clear timestamps and scopes.
- Adaptive assignment can amplify bad reward signals if outcomes are delayed, sparse, biased, or joined to the wrong exposure.
- Adaptive policy state must be reproducible and auditable enough for research review.
- Thompson Sampling can shift traffic away from lower-performing conditions before a traditional fixed-split sample is complete; researchers need explicit monitoring and export semantics so adaptive runs are not interpreted as fixed randomized controlled trials.
- Binary reward definitions may oversimplify learning outcomes if correctness is noisy, delayed, or misaligned with the intervention's intended effect.
- Group assignment semantics require careful mapping to Torus institutions, sections, LMS groups, products, and enrollments.
- Published content immutability must be respected. Experiment delivery choices should not mutate published revisions.
- Multi-tenancy and institution scoping must be explicit in all reads and writes.
- Service API request and response contracts must be stable enough for delivery, authoring, analytics, and adaptive policy work to proceed independently.

## Open Questions

- What exact API surfaces should the A/B testing service expose for delivery, authoring, analytics, and reward feedback?
- What repository or module boundaries should prevent other Torus contexts from directly accessing A/B testing schemas and tables?
- Should native experiments be authored at project level, section level, or both?
- Should assignment happen at first page render, first decision point render, or first attempt creation?
- Should experiment outcome analytics join existing Torus attempt data or store explicit event metrics?
- What exact binary reward signal should drive MVP Thompson Sampling: correctness, completion, configured attempt outcome, or another success/failure metric?
- Should MVP Thompson Sampling be implemented fully inside Torus, integrated through an external policy service, or both behind an adapter?
- Which follow-on reward models should be supported after MVP binary rewards: score delta, time-on-task, later mastery, continuous rewards, or configurable metrics?
- How should delayed rewards update algorithm state when an assignment happened much earlier?
- What guardrails are required for Thompson Sampling, such as minimum sample sizes, traffic caps, fixed control allocation, or manual pause thresholds?
- What minimum analytics do researchers/instructors need before native A/B testing is broadly available?
- Who can create, start, pause, complete, or archive experiments?
- Should experiments be visible to course authors only, administrators only, or instructors in delivered sections?
- Should experiment assignment be deterministic without persistence, persisted only, or deterministic plus persisted?
- What should happen when authors edit condition options after learners have assignments?

## Initial Effort Estimate

Rough implementation phases:

- Phase 1: A/B testing service boundary, native service-owned persistence, delivery assignment API, baseline weighted assignment, Thompson Sampling policy contracts/state shape, and anti-corruption around the current UpGrade-shaped runtime interface, 8-11 weeks.
- Phase 2: native-only authoring gate, UpGrade removal, and hard cut-over to native delivery through the service API, 3-5 weeks.
- Phase 3: Authoring/admin lifecycle, basic analytics, and reward/outcome plumbing through service APIs/read models, 6-8 weeks.
- Phase 4: Thompson Sampling implementation, adaptive guardrails, posterior-state auditability, and monitoring, plus richer native group assignment, segments, and audit logs, 10-14 weeks.
- Phase 5: advanced parity such as factorial, stratified sampling, within-subjects, or feature flags, 2-4+ months depending on chosen scope.

These estimates assume existing Torus authoring and delivery patterns are reused through a new A/B testing service API. Treating A/B testing as a separate monolith-internal service adds contract design, API adapters, boundary tests, and review overhead, but it also reduces long-term coupling and leaves a clearer path to future extraction if that ever becomes necessary. Including adaptive assignment increases the importance of outcome/reward modeling, policy-state auditability, and careful rollout controls.
