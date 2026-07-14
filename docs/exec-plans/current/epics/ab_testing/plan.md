# Built-in A/B Testing Roadmap

Last updated: 2026-06-30

Context reference:

- `docs/exec-plans/current/epics/ab_testing/informal.md`
- `docs/exec-plans/current/epics/ab_testing/references/EASI_ThompsonSampling.ipynb`

## Purpose

This roadmap coordinates replacing Torus's external UpGrade dependency with native A/B testing support through a hard cut-over. It is a parent roadmap for multiple child work items, not a phase-by-phase implementation plan for the whole epic.

The MVP should maintain the simple A/B/N alternatives behavior Torus uses today while adding native adaptive assignment through Thompson Sampling, native lifecycle controls, analytics, and end-to-end release verification. Selected advanced capabilities remain possible follow-on work only when they become explicit product requirements.

## Core Direction

- Build A/B testing as a dedicated Torus domain/context with explicit data ownership, Torus-owned persistence, and context APIs instead of runtime HTTP calls to UpGrade.
- Keep delivery, authoring, and analytics code behind A/B testing domain APIs or approved read models; they must not query or mutate experiment-owned persistence directly.
- Maintain current learner-facing alternatives behavior, including sticky native assignment and first-option fallback when no active native experiment applies.
- Treat assignment algorithms as a first-class internal boundary inside the A/B testing domain, with weighted deterministic random assignment as the baseline non-adaptive policy and Thompson Sampling as the required MVP adaptive policy.
- Implement Thompson Sampling initially as a non-contextual Beta-Bernoulli policy for binary rewards, following `docs/exec-plans/current/epics/ab_testing/references/EASI_ThompsonSampling.ipynb`.
- Include the assignment, exposure, outcome, reward, and policy-state paths needed for Thompson Sampling without forcing delivery code to know which algorithm is active.
- Make a hard cut-over to native A/B testing; legacy UpGrade runtime assignment, mark, and log support does not continue with the new feature.
- Do not migrate existing or in-progress UpGrade-based experiments; native A/B testing is a new feature and all learners are new participants in native experiments.
- Remove UpGrade-specific authoring copy, JSON export workflow, configuration, and runtime dependencies as part of the native cut-over.

## Current Foundation

Torus currently uses UpGrade narrowly:

- `lib/oli/delivery/experiments.ex` initializes users, assigns conditions, marks applied decision points, and logs metrics through UpGrade HTTP endpoints.
- `lib/oli/resources/alternatives/decision_point_strategy.ex` asks the experiment provider for a condition and caches the selected condition in section extrinsic state.
- `lib/oli/delivery/experiments/log_worker.ex` posts correctness metrics after evaluated activity attempts.
- `lib/oli/delivery/experiments/experiment_builder.ex` and `lib/oli/delivery/experiments/segment_builder.ex` generate UpGrade import JSON.
- `lib/oli_web/live/workspaces/course_author/experiments_live.ex` and `lib/oli_web/live/experiments/experiments_live.ex` expose the current authoring and JSON-download workflow.
- `priv/repo/migrations/20230302142539_has_experiments.exs` stores the current project and section experiment-enabled flag.

The current product surface is effectively simple alternatives experimentation: a project or section is experiment-enabled, an alternatives decision point contains condition options, delivery assigns an enrollment to one condition, that condition controls visible alternative content, and correctness is logged asynchronously.

Important constraint: existing and in-progress UpGrade-backed experiments are not migrated into native experiment records. Native A/B testing starts fresh: new native experiments are authored in Torus, native assignments start from the native A/B testing domain, and all learners are considered new participants for native experiments.

## Sequencing Principles

- Establish the A/B testing domain boundary, public context APIs, data ownership rules, and anti-corruption layer before replacing runtime delivery calls.
- Require all cross-domain interactions to go through context request/response shapes, commands, queries, events, or approved read models instead of shared schemas or direct repository access.
- Treat native A/B testing as a new feature: route all new experiments to native authoring and native assignment, and do not import existing UpGrade experiments or learner assignments.
- Put assignment, exposure, outcome, reward, and algorithm boundaries in place before enabling Thompson Sampling in production.
- Keep authoring UI changes behind stable native runtime behavior, and deliver weighted random authoring/lifecycle before adaptive authoring controls.
- Build analytics only after assignment, exposure, reward, and policy-state evidence has a reliable source of truth through the corrected operational-state and xAPI/ClickHouse boundaries.
- Treat advanced UpGrade parity as follow-on product scope, not as a blocker for removing the dependency.
- Respect published content immutability; experiments choose delivery alternatives without mutating published revisions.

## Feature Sequence

### 1. A/B Testing Domain Boundary And API Contract

Likely directory: `docs/exec-plans/current/epics/ab_testing/domain_contract/`

Deliver:

- A monolith-internal A/B testing domain boundary with explicit ownership of experiment definitions, decision points, conditions, assignments, exposures, events or outcome associations, rewards, and algorithm state.
- Context APIs for delivery-time assignment/exposure, authoring/lifecycle, analytics reads, and reward/outcome feedback.
- API request and response types that use domain language and stable IDs instead of leaking Ecto schemas, query details, or implementation tables across boundaries.
- An anti-corruption layer from current UpGrade-shaped provider behavior into native domain commands and queries during replacement.
- Rules that prevent delivery, authoring, and analytics code from directly querying or mutating A/B testing persistence.
- Assignment algorithm behavior contracts such as `assign_condition` and `record_reward` inside the A/B testing domain.
- Baseline support for individual assignment by enrollment, weighted deterministic random assignment, and Thompson Sampling policy state contracts.
- Thompson Sampling state shape for per-condition Beta posterior parameters, prior configuration, algorithm name/version, and reproducible update metadata.
- Multi-tenant scoping rules for project, section, user, and enrollment data at the domain API boundary.

Defer:

- Authoring UI redesign.
- Full lifecycle controls beyond what is needed to validate active versus inactive experiments.
- Analytics dashboards.
- Extraction into an external service or separately deployed runtime.
- Advanced UpGrade parity such as factorial experiments, stratified sampling, feature flags, and within-subject assignment.

Dependencies:

- Existing alternatives resources and section extrinsic state behavior.
- Existing `has_experiments` project and section flags.

Why this comes here:

- Runtime replacement, analytics, and Thompson Sampling all need a durable native source of truth and stable context APIs before they can be implemented safely. Making the boundary explicit first prevents later slices from coupling directly to tables or implementation modules.

Expected child artifacts:

- `docs/exec-plans/current/epics/ab_testing/domain_contract/prd.md`
- `docs/exec-plans/current/epics/ab_testing/domain_contract/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/domain_contract/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/domain_contract/plan.md`

### 2. Native Cut-Over And UpGrade Removal

Likely directory: `docs/exec-plans/current/epics/ab_testing/native_cutover/`

Deliver:

- Native-only authoring gate for all new experiments.
- Explicit non-migration rule for existing or in-progress UpGrade-backed experiments.
- Native participant rule: every learner is treated as a new participant for native experiments.
- Authoring rules that prevent new UpGrade-backed experiment creation and route all new experiment authoring to native definitions.
- Removal or disabling of the UpGrade JSON export/import workflow.
- Hard cut-over controls that remove runtime dependence on UpGrade assignment, mark, and log calls.
- Removal of UpGrade configuration and obsolete runtime integration paths once native delivery is active.

Explicitly exclude:

- Migration of existing or in-progress UpGrade-backed experiments.
- Preservation or import of UpGrade learner assignments.
- Historical UpGrade analytics import.
- Continuing UpGrade runtime assignment, mark, or log support after cut-over.

Dependencies:

- Native domain APIs, persistence, experiment identity rules, and assignment records from `domain_contract`.
- Existing UpGrade authoring and runtime entry points that must be disabled or removed.

Why this comes here:

- Native delivery can become authoritative only after new authoring is routed to native definitions and the UpGrade runtime path is no longer used for new feature behavior. This comes before runtime replacement because delivery must only call the native A/B testing domain APIs for native experiments.

Expected child artifacts:

- `docs/exec-plans/current/epics/ab_testing/native_cutover/prd.md`
- `docs/exec-plans/current/epics/ab_testing/native_cutover/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/native_cutover/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/native_cutover/plan.md`

### 3. Native Delivery Runtime Replacement

Likely directory: `docs/exec-plans/current/epics/ab_testing/delivery_runtime/`

Deliver:

- Native assignment, exposure, and reward runtime calls through A/B testing domain APIs for native experiments.
- Sticky assignment reuse from A/B testing-owned assignment records.
- Native first assignment for all learners entering native experiments.
- Exposure recording when decision point content is applied.
- Correct fallback behavior when no active experiment applies.
- Correctness or outcome association after evaluated activity attempts.
- Reward event recording that can later update Thompson Sampling posterior state without duplicating reward counts.
- Runtime tests for stickiness, weights, fallback, exposure logging, project/section gating, attempt outcome association, and idempotent reward handoff.

Defer:

- Rich authoring lifecycle controls.
- Research dashboards.
- Rich adaptive policy tuning UI beyond the MVP controls required to enable Thompson Sampling safely.
- Continuing UpGrade runtime assignment, mark, or log support after cut-over.

Dependencies:

- Native A/B testing domain APIs and persistence.
- Native cut-over and UpGrade removal readiness.

Why this comes here:

- This is the dependency-removal center of the epic. It follows native cut-over readiness because delivery is where learner-facing behavior can be disrupted if assignment, exposure, fallback, and reward behavior are not fully native.

Expected child artifacts:

- `docs/exec-plans/current/epics/ab_testing/delivery_runtime/prd.md`
- `docs/exec-plans/current/epics/ab_testing/delivery_runtime/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/delivery_runtime/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/delivery_runtime/plan.md`

### 4. Native Authoring And Experiment Lifecycle

Likely directory: `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle/`

Deliver:

- Authoring updates that remove UpGrade-specific copy and JSON download workflows.
- Native create, edit, start, pause, complete, and archive behavior where required.
- Configurable condition weights for simple A/B/N experiments.
- Weighted random experiment authoring and lifecycle activation as the first native authoring path.
- Disabled or absent Thompson Sampling affordances; if shown, the UI says "Coming soon" and cannot submit, persist, or activate adaptive experiments.
- Validation rules for condition changes after assignments exist.
- Start and end date support if required for native lifecycle parity.
- Permission rules allowing accepted project collaborators, content admins, account admins, and system admins to start, pause, complete, or archive experiments.

Defer:

- Full UpGrade admin UI parity.
- Preview users and preview assignments unless required for the initial native authoring release.
- Thompson Sampling selection, policy configuration, guardrail tuning, and adaptive experiment activation.
- Advanced segments, factorial designs, and feature flags.

Dependencies:

- A/B testing-owned persistence and lifecycle state validation.
- Delivery runtime replacement semantics for active experiment states.
- Authoring-facing A/B testing context APIs rather than direct table access.

Why this comes here:

- Authors should not manage native lifecycle controls until the runtime model is stable enough for those controls to have predictable delivery effects. Weighted random authoring can ship before Thompson Sampling so authors can create and manage the baseline native workflow while adaptive behavior remains unavailable.

Expected child artifacts:

- `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle/prd.md`
- `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle/plan.md`

### 5. Thompson Sampling MVP Adaptive Policy

Likely directory: `docs/exec-plans/current/epics/ab_testing/thompson_sampling/`

Deliver:

- Native non-contextual Thompson Sampling for A/B/N alternatives experiments.
- Beta-Bernoulli binary reward model with configurable or default Beta(1,1) priors.
- Assignment-time posterior sampling across active conditions and selection of the condition with the highest sampled value.
- Reward-time posterior updates for the assigned condition only, incrementing success or failure counts from an idempotent binary reward event.
- Persisted policy state, algorithm version, prior configuration, update provenance, and enough audit metadata for research review.
- Guardrails such as warm-up or minimum sample thresholds, optional fixed control allocation, traffic caps, manual pause, and monitoring for missing rewards or extreme assignment imbalance where required for MVP operation.
- Authoring updates that replace the authoring-lifecycle slice's disabled Thompson Sampling "Coming soon" affordance with selectable adaptive experiment configuration.
- Lifecycle validation updates that allow Thompson Sampling activation only when priors, guardrails, reward readiness, and alternatives condition mappings are valid.
- LiveView/context tests for selecting Thompson Sampling, validating MVP-safe priors and guardrails, activating adaptive experiments, preserving sticky assignments, and falling back to weighted random when adaptive selection is unavailable.

Defer:

- Contextual Thompson Sampling using participant or course features.
- Continuous reward models, score-delta optimization, delayed mastery optimization, or multi-objective rewards.
- Batch or parallel Thompson Sampling updates beyond what is needed for reliable Oban-backed reward processing.
- Every UpGrade or Mooclet adaptive variant other than the required MVP Thompson Sampling policy.

Dependencies:

- Stable assignment algorithm boundary and Thompson Sampling state contracts from `domain_contract`.
- Delivery runtime reward handoff and exposure/outcome records from `delivery_runtime`.
- Weighted random authoring lifecycle, disabled adaptive affordance, and assignment-aware edit rules from `authoring_lifecycle`.

Why this comes here:

- Thompson Sampling remains required MVP adaptive scope, but it should follow the weighted random authoring lifecycle slice so the first authoring release can ship without implementing adaptive policy controls. This slice owns the policy implementation and the authoring changes needed to turn the deferred "Coming soon" affordance into a real selectable adaptive workflow.

Expected child artifacts:

- `docs/exec-plans/current/epics/ab_testing/thompson_sampling/prd.md`
- `docs/exec-plans/current/epics/ab_testing/thompson_sampling/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/thompson_sampling/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/thompson_sampling/plan.md`

### 6. Runtime Telemetry Reconciliation

Likely directory: `docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation/`

Deliver:

- A reconciliation pass over slices 1-5 so already-implemented native A/B testing work follows the new scalable data boundary before analytics development continues.
- Clear classification of existing implementation as keep, modify, remove, or defer.
- A corrected source-of-truth boundary:
  - PostgreSQL remains authoritative for experiment definitions, decision points, conditions, lifecycle state, sticky assignment state required for delivery correctness, and current adaptive policy state required for runtime assignment.
  - xAPI JSONL in S3 becomes the durable event source for assignment, exposure, outcome, reward, and policy-update history.
  - ClickHouse becomes the analytics serving store for dashboards, reports, and dataset exports.
- Replacement or quarantine of PostgreSQL-heavy event-log and aggregate-reporting assumptions from prior slices.
- Updated context contracts so delivery can emit experiment xAPI statements while preserving idempotent runtime behavior.
- Regression tests or review checks that prevent product dashboards, exports, and large aggregates from querying PostgreSQL experiment event tables.
- A migration/cutover note for any already-created `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, or `experiment_policy_updates` usage: these tables may be retained only as transitional operational scaffolding or removed if no longer needed, but they are not the product analytics source.

Defer:

- New ClickHouse schema, ETL projections, dashboards, and dataset downloads beyond contract changes needed to unblock the OLAP foundation slice.
- Redesign of authoring lifecycle or student delivery UI.
- New adaptive algorithms.

Dependencies:

- Implemented slices 1-5, including current `Oli.Experiments` APIs, native runtime replacement, authoring lifecycle, and Thompson Sampling policy state.
- Existing xAPI upload pipeline and ClickHouse OLAP infrastructure.

Why this comes here:

- The new scalability requirement invalidates the previous analytics source-of-truth assumption. Reconciliation must happen before analytics or dashboard work so future slices do not deepen coupling to PostgreSQL event logs or aggregates.

Expected child artifacts:

- `docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation/prd.md`
- `docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation/plan.md`

### 7. Experiment XAPI And OLAP Foundation

Likely directory: `docs/exec-plans/current/epics/ab_testing/experiment_olap_foundation/`

Deliver:

- Canonical xAPI statement shapes for experiment assignment, sticky assignment reuse, exposure, outcome/reward observation, and adaptive policy update events.
- Required experiment identifiers and scope fields in statements, including experiment ID/UUID, project, section, publication where available, decision point, condition, enrollment or learner reference where allowed, activity/page/resource references, algorithm, policy version, idempotency key, and event timestamp.
- Updates to the Torus xAPI emitters so experiment runtime paths emit statements without adding heavy synchronous database logging.
- Updates to the production ETL path so experiment statements land in ClickHouse with queryable columns or approved projections.
- Updates to local direct ClickHouse upload and backfill behavior so local development, rebuilds, and historical reloads preserve experiment events.
- ClickHouse schema or materialized-view support for project-level and section-level experiment analytics.
- Dataset/export integration so experiment event data can be downloaded through the existing dataset infrastructure.
- Scoped analytics query contracts that read from ClickHouse for dashboards, reports, and exports.
- Data-quality and observability checks for xAPI emission failures, ETL lag, ClickHouse query failures, missing exposure/outcome/reward events, and delayed policy-update evidence.

Defer:

- Final dashboard UX beyond query contracts and minimum surfaces needed by the analytics slice.
- Complex metric-query language parity with UpGrade.
- Long-term research warehouse product decisions beyond reusing the existing xAPI/S3/ClickHouse path.

Dependencies:

- Runtime telemetry reconciliation.
- Existing xAPI pipeline, S3 JSONL durable event source, Lambda/SQS ETL path, ClickHouse migrations, backfill jobs, and dataset infrastructure.
- Runtime assignment, exposure, reward handoff, and Thompson Sampling policy state from earlier slices.

Why this comes here:

- Analytics must be powered by the scalable event and OLAP infrastructure before project-level or section-level dashboards are built. This slice establishes that foundation and keeps large aggregates out of PostgreSQL.

Expected child artifacts:

- `docs/exec-plans/current/epics/ab_testing/experiment_olap_foundation/prd.md`
- `docs/exec-plans/current/epics/ab_testing/experiment_olap_foundation/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/experiment_olap_foundation/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/experiment_olap_foundation/plan.md`

### 8. Outcome Analytics And Research Visibility

Likely directory: `docs/exec-plans/current/epics/ab_testing/analytics/`

Deliver:

- Assignment and exposure analytics by experiment, decision point, condition, project, and section, backed by ClickHouse query contracts or projections.
- Outcome reporting based on experiment xAPI events joined to existing attempt xAPI data and approved ClickHouse projections.
- Clear timestamp and scope semantics for joining assignments, exposures, experiment rewards, policy updates, and activity attempts in OLAP queries.
- Basic monitoring for missing exposures, missing outcomes, failed reward updates, ETL lag, ClickHouse query failures, and unexpected assignment imbalance.
- Thompson Sampling monitoring for current PostgreSQL runtime policy state plus ClickHouse-backed reward counts, policy-update event history, assignment share over time, missing/delayed rewards, and guardrail-triggered pauses.
- Project-level and section-level dashboards or reporting surfaces needed before native A/B testing is broadly available.
- Dataset/download coverage for experiment data using the existing dataset infrastructure.

Defer:

- Complex metric-query language parity with UpGrade.
- New warehouse or research-data product infrastructure beyond the existing xAPI/S3/ClickHouse path.
- Advanced adaptive algorithm monitoring beyond the fields needed to validate Thompson Sampling reward flow and posterior state.

Dependencies:

- Runtime telemetry reconciliation.
- Experiment xAPI and OLAP foundation.
- ClickHouse projections or query APIs for experiment assignment, exposure, reward/outcome, and policy-update events.
- Current Thompson Sampling policy state for runtime inspection and OLAP event history for research/audit analytics.
- Lifecycle states that define which experiments should appear in reporting.
- Analytics-facing A/B testing queries or read models rather than direct PostgreSQL event-table access.

Why this comes here:

- Analytics should be built after experiment telemetry is flowing through xAPI and ClickHouse. Building dashboards earlier would report against a transitional PostgreSQL event-log model that does not meet the new scalability requirement.

Expected child artifacts:

- `docs/exec-plans/current/epics/ab_testing/analytics/prd.md`
- `docs/exec-plans/current/epics/ab_testing/analytics/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/analytics/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/analytics/plan.md`

### 9. End-To-End Manual QA Verification

Likely directory: `docs/exec-plans/current/epics/ab_testing/manual_qa/`

Deliver:

- A manual QA verification script that covers the A/B testing workflow from authoring through instructor and student delivery.
- Setup instructions for creating or selecting a project, section, instructor, and multiple student users needed to exercise assignment behavior.
- Non-adaptive A/B/N verification using weighted deterministic random assignment, sticky assignment reuse, first-option fallback when no active experiment applies, exposure recording, outcome/reward handoff, and instructor/research visibility.
- Thompson Sampling adaptive verification using a binary reward signal, posterior state changes, sticky assignment after policy updates, guardrail behavior where visible, and analytics/monitoring evidence for reward counts and assignment share.
- Role-based checks for authoring permissions, instructor-facing delivery or reporting surfaces, and student-facing alternative content rendering.
- Pass/fail evidence expectations such as screenshots, database-safe identifiers, analytics snapshots, log-free test notes, and known cleanup steps.
- A first completed QA run against the native A/B testing implementation before broad rollout.

Defer:

- Fully automated browser coverage for every manual QA step.
- Load, distribution, or long-running statistical validation beyond what is needed to sanity-check weights and adaptive updates manually.
- Manual QA coverage for advanced parity features that are not part of the initial native release.

Dependencies:

- Native delivery runtime replacement.
- Native authoring lifecycle controls for creating and activating non-adaptive and Thompson Sampling experiments.
- Thompson Sampling reward processing, policy state, and guardrails needed for MVP adaptive behavior.
- Analytics or monitoring surfaces that show assignment, exposure, reward, and posterior-state evidence.

Why this comes here:

- End-to-end QA should happen after the core product surfaces and algorithm evidence are visible, but before additional adaptive policies or advanced parity broaden the test matrix. This slice gives release reviewers a repeatable script for validating both baseline and adaptive workflows across roles.

Expected child artifacts:

- `docs/exec-plans/current/epics/ab_testing/manual_qa/prd.md`
- `docs/exec-plans/current/epics/ab_testing/manual_qa/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/manual_qa/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/manual_qa/plan.md`

## Post-MVP Follow-On Candidates

The following items are intentionally outside the MVP. They should remain visible as possible follow-on work, but they are not required for the initial native A/B testing cut-over, Thompson Sampling MVP, or release verification.

### Additional Adaptive Assignment Policies

Likely directory: `docs/exec-plans/current/epics/ab_testing/adaptive_policies/`

Possible future scope:

- Additional adaptive assignment policies or policy adapters selected from product and research requirements after MVP Thompson Sampling.
- Reward-feedback handling for delayed, sparse, biased, or missing outcomes.
- Policy state persistence and auditability.
- Guardrails such as minimum sample sizes, traffic caps, fixed control allocation, and manual pause thresholds where required.
- Monitoring that helps researchers and administrators understand adaptive behavior.

Defer:

- Every UpGrade or Mooclet algorithm variant unless explicitly required.
- Contextual bandit support unless the reward and context model justifies it.
- Advanced group assignment, segments, and factorial policies that belong to later parity work.

Would depend on:

- Stable assignment algorithm boundary from `domain_contract`.
- Reliable outcome and reward plumbing from delivery runtime and analytics work.
- MVP Thompson Sampling implementation and operational learnings.
- Lifecycle controls that can pause or stop risky adaptive behavior.
- Completed end-to-end QA findings for the MVP non-adaptive and Thompson Sampling workflows.

Why this is post-MVP:

- Thompson Sampling handles the MVP adaptive requirement. Additional adaptive policies depend on trustworthy assignment, exposure, outcome, reward, and monitoring loops, and should only be prioritized after the initial native workflow has been validated and a concrete product or research need exists.

Possible child artifacts:

- `docs/exec-plans/current/epics/ab_testing/adaptive_policies/prd.md`
- `docs/exec-plans/current/epics/ab_testing/adaptive_policies/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/adaptive_policies/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/adaptive_policies/plan.md`

### Advanced Experiment Parity

Likely directory: `docs/exec-plans/current/epics/ab_testing/advanced_parity/`

Possible future scope:

- Product-selected UpGrade parity features after the native replacement is stable.
- Candidate capabilities include group assignment, inclusion and exclusion segments, multiple decision points per experiment, post-experiment behavior, factorial conditions, stratified sampling, within-subject assignment, feature flags, audit logs, and preview users.
- A prioritization model that distinguishes required native product features from compatibility conveniences.

Defer:

- Any advanced capability that does not have a clear Torus product use case or native feature need.

Would depend on:

- Native runtime replacement.
- Authoring lifecycle and analytics foundations.
- Thompson Sampling and additional adaptive policy work where advanced parity affects algorithm selection or reward modeling.
- Completed end-to-end QA findings for the initial native release workflow.

Why this is post-MVP:

- Full UpGrade parity is a substantially larger platform effort. It should not block removing the external dependency for the simple alternatives workflow Torus uses today, and individual parity features should be pulled forward only when tied to a current Torus need or explicit roadmap commitment.

Possible child artifacts:

- `docs/exec-plans/current/epics/ab_testing/advanced_parity/prd.md`
- `docs/exec-plans/current/epics/ab_testing/advanced_parity/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/advanced_parity/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/advanced_parity/plan.md`

### Section Participation Controls

Likely directory: `docs/exec-plans/current/epics/ab_testing/section_participation/`

Possible future scope:

- Section-level controls for whether a course section participates in A/B testing experiments authored in its source project materials.
- A high-level section participation toggle that defaults to enabled when a section is created from project materials with active or authorable A/B testing.
- Fine-grained source-project participation controls for sections that contain materials from multiple source projects through remix or template/product source materials.
- Default participation enabled for newly remixed source projects that contain A/B testing experiments.
- Product/template inheritance so sections created from a template inherit both the high-level participation setting and any per-source-project participation settings from the template.
- Runtime gating that checks section participation before assignment, exposure, and reward handling without changing project-level experiment authoring.

Defer:

- This is not MVP scope and should not block the initial A/B testing cut-over, project-level authoring lifecycle, delivery runtime replacement, Thompson Sampling MVP, analytics, or manual QA verification.
- Per-section experiment definitions; experiments remain authored at the project level unless a later product requirement explicitly changes that model.

Would depend on:

- Project-level A/B testing authoring and lifecycle controls.
- Delivery runtime assignment through `Oli.Experiments` request/scope APIs.
- Reliable `sections_projects_publications` source-project mappings for base, remixed, and template-derived materials.
- Template/product duplication and section creation paths that can copy participation settings.

Why this is post-MVP:

- The previous UpGrade-shaped workflow had project-level authoring plus coarse project/section enablement, not fine-grained per-source-project participation controls. The MVP can preserve that behavior while leaving a clean path for later section participation controls as an additive gating layer before runtime assignment.
- Existing section/source-project mapping infrastructure makes this feasible later, but remixed-content correctness will require runtime resolution of the source project for the alternatives resource rather than assuming only the section base project.

Possible child artifacts:

- `docs/exec-plans/current/epics/ab_testing/section_participation/prd.md`
- `docs/exec-plans/current/epics/ab_testing/section_participation/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/section_participation/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/section_participation/plan.md`

## Slice Dependency Graph

```mermaid
flowchart TD
  subgraph MVP["MVP Deliverables"]
  DOMAIN["Domain Contract"]
  CUTOVER["Native Cut-Over"]
  DELIVERY["Delivery Runtime"]
  TS["Thompson Sampling"]
  AUTHORING["Authoring Lifecycle"]
  RECONCILE["Runtime Telemetry Reconciliation"]
  OLAP["Experiment XAPI And OLAP"]
  ANALYTICS["Analytics"]
  QA["Manual QA"]
  end

  subgraph FOLLOWON["Post-MVP Follow-On Candidates"]
  ADAPTIVE["Additional Adaptive Policies"]
  PARITY["Advanced Parity"]
  PARTICIPATION["Section Participation Controls"]
  end

  DOMAIN --> CUTOVER
  DOMAIN --> DELIVERY
  CUTOVER --> DELIVERY
  DELIVERY --> AUTHORING
  DOMAIN --> AUTHORING
  DOMAIN --> TS
  DELIVERY --> TS
  AUTHORING --> TS
  DOMAIN --> RECONCILE
  DELIVERY --> RECONCILE
  AUTHORING --> RECONCILE
  TS --> RECONCILE
  RECONCILE --> OLAP
  OLAP --> ANALYTICS
  TS --> ANALYTICS
  AUTHORING --> ANALYTICS
  DELIVERY --> QA
  TS --> QA
  AUTHORING --> QA
  ANALYTICS --> QA
  QA --> ADAPTIVE
  QA --> PARTICIPATION
  QA --> PARITY
  PARTICIPATION --> PARITY
  ADAPTIVE --> PARITY
```

## Cross-Cutting Concerns

- Cutover: existing and in-progress UpGrade experiments are not migrated; native A/B testing starts as a new feature, all learners are new participants in native experiments, and UpGrade runtime assignment/mark/log calls are removed.
- Domain boundary and API discipline: A/B testing is a dedicated Torus domain/context inside the monolith; other Torus domains should depend on its context APIs, approved queries, events, or read models, not its schemas, private queries, or tables.
- Data ownership and persistence: PostgreSQL should remain the source of truth for low-volume operational state such as experiment definitions, decision points, conditions, lifecycle state, sticky assignment state needed for delivery correctness, and current adaptive policy state needed for runtime decisions. PostgreSQL should not be the heavy event log or dashboard/export source for assignments, exposures, outcomes, rewards, or policy-update history.
- Event and analytics source of truth: xAPI JSONL in S3 should be the durable source for experiment event history, and ClickHouse should be the serving store for project dashboards, section dashboards, large aggregate reports, and dataset exports. Any PostgreSQL event rows retained from slices 1-5 are transitional operational scaffolding unless a later design explicitly justifies them.
- Security and privacy: all reads and writes must be scoped by institution, project, section, user, and enrollment as appropriate; research exports must avoid exposing unnecessary learner data.
- Published content immutability: experiment choices can select alternatives at delivery time but must not mutate published revisions.
- Reliability and performance: assignment should remain local and transactional, avoid repeated remote calls, and preserve fallback behavior when no active experiment applies. Heavy event creation and analytics queries should use the xAPI/ClickHouse path rather than high-volume PostgreSQL writes or dashboard aggregates.
- Observability and auditability: assignment decisions, exposures, failed outcome joins, reward updates, Thompson Sampling posterior updates, lifecycle changes, and adaptive policy updates should be inspectable through xAPI/ClickHouse-backed evidence, with current runtime policy state inspectable from the A/B testing domain where needed.
- Testing and verification: coverage should include assignment stickiness, weighted distribution behavior, Thompson Sampling posterior sampling and updates, fallback behavior, experiment xAPI emission, ClickHouse projection/query behavior, dataset export inclusion, project and section analytics scoping, project and section gating, native-only authoring gates, first-assignment behavior for all learners, attempt outcome association, permission checks, lifecycle transitions, and an end-to-end manual QA script that verifies authoring through instructor and student delivery for both non-adaptive and Thompson Sampling use cases.
- MVP scope control: the MVP includes native cut-over, weighted deterministic random assignment, Thompson Sampling, authoring/lifecycle, analytics/monitoring needed for release confidence, and end-to-end manual QA. Additional adaptive policies and advanced UpGrade parity are post-MVP follow-on candidates, not necessary MVP deliverables.

## Initial Effort Estimate

These rough ranges assume existing Torus authoring and delivery patterns are reused through A/B testing context APIs. Treating A/B testing as a dedicated domain with owned persistence adds contract design, boundary tests, and review overhead, but it also reduces long-term coupling and leaves a clearer path to future extraction if that ever becomes necessary.

Rough implementation shape:

- A/B testing domain boundary, A/B testing-owned persistence, delivery assignment API, baseline weighted assignment, Thompson Sampling policy contracts/state shape, and anti-corruption around the current UpGrade-shaped runtime interface: 8-11 weeks.
- Native-only authoring gate, UpGrade removal, and hard cut-over to native delivery through domain APIs: 3-5 weeks.
- Weighted random authoring lifecycle and reward/outcome plumbing through context APIs and xAPI emission contracts: 6-8 weeks.
- Thompson Sampling implementation, adaptive guardrails, current runtime posterior state, xAPI policy-update evidence, monitoring contracts, and the authoring updates needed to enable adaptive experiment selection: 10-14 weeks.
- Runtime telemetry reconciliation for already-completed slices 1-5: 1-3 weeks, depending on how much PostgreSQL event-log code is removed versus retained as transitional scaffolding.
- Experiment xAPI/ClickHouse OLAP foundation, including statement definitions, ETL/direct uploader/backfill updates, ClickHouse schema/projections, dataset export integration, and scoped query contracts: 4-7 weeks.
- Outcome analytics and research dashboards backed by ClickHouse query contracts or projections: 3-6 weeks.
- End-to-end manual QA script authoring, test data setup, and first completed verification run across authoring, instructor, and student workflows: 1-2 weeks.

Post-MVP follow-on candidates:

- Additional adaptive policies, richer native group assignment, segments, and audit logs: estimate after concrete product or research scope is selected.
- Section-level and per-source-project participation controls: estimate after MVP runtime and authoring surfaces settle.
- Advanced parity such as factorial, stratified sampling, within-subjects, or feature flags: 2-4+ months depending on selected scope.

## Open Questions

- What exact context API surfaces should the A/B testing domain expose for delivery, authoring, analytics, and reward feedback?
- What repository or module boundaries should prevent other Torus contexts from directly accessing A/B testing schemas and tables?
- Should assignment occur at first page render, first decision point render, or first attempt creation?
- Which already-implemented PostgreSQL event tables and APIs should be removed, retained as transitional operational scaffolding, or repurposed only for idempotency/current runtime behavior?
- Which experiment xAPI statement verbs, object types, and extension keys should be canonical for assignment, exposure, reward/outcome, and policy-update events?
- Should outcome analytics join experiment xAPI events to existing attempt xAPI events in ClickHouse, emit explicit experiment outcome events, or do both for MVP?
- What ClickHouse table/projection shape should support project-level dashboards, section-level dashboards, and dataset exports without expensive ad hoc joins?
- Should MVP Thompson Sampling run fully inside the A/B testing domain, behind an external policy adapter, or inside Torus first with a future extraction boundary?
- What binary reward signal should drive MVP Thompson Sampling: correctness, completion, configured attempt success, or another success/failure metric?
- What guardrails are required before Thompson Sampling can run in production?
- What minimum analytics do researchers, authors, instructors, and administrators need before native A/B testing is broadly available?
- What operational alerts or dashboards are required for xAPI emission failures, ETL lag, ClickHouse ingest/query failures, and missing experiment event evidence?
- What canonical course, section, instructor, and student fixtures should the manual QA script use for repeatable non-adaptive and Thompson Sampling verification?
- What should happen when authors edit condition options after learners already have assignments?

## Recommended Next Slice

Start with `docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation/` because slices 1-5 were defined and implemented under the previous PostgreSQL-heavy analytics assumption. Use `harness-analyze` next to create `docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation/prd.md`, then use `harness-architect` for the reconciliation FDD before implementing slice 6.

## Decision Log
### 2026-07-14 - Reconcile Native A/B Testing With XAPI/ClickHouse Analytics
- Change: Inserted `Runtime Telemetry Reconciliation` and `Experiment XAPI And OLAP Foundation` before analytics, moved outcome analytics to slice 8, and moved manual QA to slice 9.
- Reason: Product requirements now require experiment event history, dashboards, and dataset exports to use the existing xAPI/S3/ClickHouse infrastructure rather than PostgreSQL-heavy event logging or aggregate analytics.
- Evidence: Current roadmap sections 6-8 and cross-cutting data ownership rules.
- Impact: Slices 1-5 remain partially valid for operational behavior, but their PostgreSQL event-log and analytics assumptions must be reconciled before analytics development continues. PostgreSQL remains appropriate for low-volume operational state and current adaptive policy state; xAPI/S3/ClickHouse becomes the durable event and analytics path.

### 2026-06-30 - Sequence Thompson Sampling After Authoring Lifecycle
- Change: Moved weighted random authoring lifecycle before Thompson Sampling and made the Thompson Sampling slice responsible for enabling adaptive authoring controls.
- Reason: The first authoring lifecycle slice should proceed without implementing Thompson Sampling, leaving adaptive controls absent or disabled until policy behavior is ready.
- Evidence: `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle/prd.md`; `docs/exec-plans/current/epics/ab_testing/thompson_sampling/prd.md`.
- Impact: `authoring_lifecycle` owns weighted random authoring and blocks adaptive activation; `thompson_sampling` owns policy implementation plus the authoring updates required to enable adaptive experiments.
