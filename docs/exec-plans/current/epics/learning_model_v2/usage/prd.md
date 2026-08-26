# Learning Model: Proficiency Reads and Usage - Product Requirements Document

## 1. Overview

This work item introduces model-aware proficiency reads for Torus delivery, dashboard, and
scenario consumers. Existing `:naive` Sections must retain their current proficiency behavior,
while Sections pinned to `:lkt_aoa` must read from the materialized LKT-AOA learner state created
by the core implementation work item.

The result is a single proficiency access path that dispatches by the persisted Section learning
model, presents a consistent estimate contract to new consumers, and adapts legacy Metrics return
shapes during migration.

## 2. Background & Problem Statement

Torus currently calculates proficiency primarily through `Oli.Delivery.Metrics` by reading
`ResourceSummary` first-attempt counts and applying the naive formula. Several consumers either call
Metrics directly or duplicate the naive calculation from summary rows. That approach cannot support
the new LKT-AOA model, whose displayed proficiency is stored as `learning_states.aoa` and whose
confidence is stored separately.

LKT-AOA state is keyed by learning objective, but existing product surfaces also ask for page,
container, course, class, and dashboard-level proficiency. Those reads need a clear aggregation
policy and a fast way to determine which learning objectives belong to a page or container without
querying delivery-time revision data.

## 3. Goals & Non-Goals

### Goals

- Keep existing `:naive` proficiency calculations, thresholds, and return contracts stable.
- Add model-aware proficiency providers that dispatch only from `Section.learning_model_version`.
- Read direct LKT-AOA learning-objective proficiency from `learning_states.aoa` and raw confidence
  from `learning_states.confidence`.
- Provide a canonical proficiency estimate shape for new consumers while adapting existing Metrics
  callers during migration.
- Support direct learning-objective, parent-objective, page, container, course, learner, and
  instructor/class aggregation where policy is defined.
- Populate page `SectionResource.related_activities` so page/container/course membership can be
  resolved from Section-pinned data and the SectionResourceDepot.
- Update dashboard oracles and scenario assertions so they use the model-aware boundary instead of
  duplicating naive formulas.
- Preserve performance by using set-based reads and SRD-backed scope membership rather than
  per-learner, per-objective, or delivery-time revision-query loops.

### Non-Goals

- Changing how LKT-AOA learner state is written.
- Changing the default learning model for new Projects or Sections.
- Exposing model selection or confidence display controls in the UI.
- Training, uploading, or editing model parameters.
- Backfilling historical `learning_states`.
- Changing descriptive Authoring Insights analytics unless a future product requirement explicitly
  adds proficiency there.
- Replacing xAPI, ClickHouse, or existing summary analytics.

## 4. Users & Use Cases

- Students: see proficiency results that reflect the Section's configured model without inconsistent
  page/objective behavior.
- Instructors: view objective, page, container, course, learner, and class proficiency using the
  model selected for their Section.
- Authors and learning engineers: rely on descriptive authoring analytics remaining separate from
  learner proficiency semantics.
- Platform engineers: maintain one proficiency read boundary with explicit model dispatch, stable
  legacy compatibility, and measurable query behavior.
- QA and scenario authors: assert proficiency for both `:naive` and `:lkt_aoa` Sections through the
  same high-level scenario directive.

## 5. UX / UI Requirements

- Existing UI surfaces should not branch directly on `learning_model_version`; model dispatch belongs
  in the proficiency read layer.
- Existing `:naive` displays must remain semantically equivalent to current behavior.
- LKT-AOA displays must show unavailable or not-enough-information states when required data or scope
  membership is unavailable. They must not silently fall back to naive values within an LKT-AOA view.
- Confidence is provided only as a raw `0.0..1.0` value in this work. Bucketing confidence into
  Low/Medium/High display categories is deferred to future UI work.
- Authoring Insights remains descriptive analytics and must not be presented as learner proficiency.

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)

Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Performance: learning-objective and learner/class reads must be set-based. Page, container, and
  course membership must use SectionResourceDepot data and must not query revisions at delivery time.
- Reliability: missing LKT-AOA state must be represented as not enough information, not as numeric
  zero. A real score of `0.0` must remain displayable.
- Compatibility: existing Metrics consumers must keep their current return shapes until explicitly
  migrated to the canonical estimate contract.
- Consistency: one rendered view must not mix naive and LKT-AOA providers.
- Privacy: proficiency reads must not expose raw PartAttempt responses or learner attempt history.
- Maintainability: model-specific formulas should live in explicit providers rather than being
  duplicated in dashboard or scenario code.

## 9. Data, Interfaces & Dependencies

- Depends on `Section.learning_model_version` from
  `docs/exec-plans/current/epics/learning_model_v2/data_model/`.
- Depends on `learning_states`, `prior_activity_part_evidence`, and Snapshot-driven LKT-AOA writes
  from `docs/exec-plans/current/epics/learning_model_v2/core_impl/`.
- Uses `Oli.Delivery.Metrics` as the legacy compatibility facade.
- Introduces a model-neutral proficiency read boundary such as `Oli.Delivery.Proficiency` with
  provider modules for `:naive` and `:lkt_aoa`.
- Introduces a canonical estimate shape carrying score, label, raw confidence, attempt counts, unique
  activity-part counts, learning-objective identity, learner identity where applicable, and model
  provenance.
- Extends `SectionResource.related_activities` semantics for page SectionResources so page rows store
  embedded activity resource IDs, while objective rows continue to store activities targeting that
  objective.
- Uses SectionResourceDepot as the delivery-time source for page, container, and course membership.

## 10. Repository & Platform Considerations

- Keep domain logic in `lib/oli/` providers and keep `lib/oli_web/` components focused on rendering
  returned values.
- Respect publication semantics: scope membership and objective mappings must use Section-pinned
  Revisions, not latest authoring Revisions.
- Delivery code should use SectionResourceDepot for page/container/course scope resolution.
- Existing `ResourceSummary` and `ResponseSummary` analytics remain valid for naive proficiency and
  descriptive analytics.
- Repository review must include security and performance lenses, plus Elixir and requirements
  review because this work changes backend read behavior and PRD traceability.
- No Jira key was supplied with this work item; implementation must not invent one.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item

Existing Sections remain `:naive` unless explicitly provisioned otherwise. LKT-AOA proficiency reads
are enabled only for Sections whose persisted `learning_model_version` is `:lkt_aoa` and whose
materialized write path is active.

The work must include a migration or repair path for populating page `SectionResource.related_activities`
for existing SectionResources if required by the selected implementation.

## 12. Telemetry & Success Metrics

- No new runtime dashboard is required.
- Performance success is demonstrated through query-count or equivalent tests showing set-based reads
  and no delivery-time revision queries for page/container/course membership.
- Functional success is demonstrated by parity tests for `:naive` Sections and LKT-AOA tests proving
  direct objective reads, scope aggregation, not-enough-information handling, dashboard oracle
  integration, and scenario assertion coverage.
- Operational success after deploy can be observed through existing request/dashboard telemetry and
  database query instrumentation.

## 13. Risks & Mitigations

- Risk: legacy Metrics return shapes are inconsistent and could leak into the new provider contract.
  Mitigation: define a canonical estimate shape and keep shape adaptation in the compatibility layer.
- Risk: LKT-AOA page/container values could accidentally use the broader contained-objective
  projection that includes direct page objectives. Mitigation: make page membership depend only on
  embedded activities and SRD `related_activities`.
- Risk: dashboard or scenario code could continue duplicating naive formulas. Mitigation: route those
  consumers through the model-aware facade and add regression tests.
- Risk: page `related_activities` database rows and SectionResourceDepot entries could diverge.
  Mitigation: update or invalidate SRD entries when post-processing changes the projection.
- Risk: missing LKT-AOA data could be misread as zero proficiency. Mitigation: make missing state an
  explicit not-enough-information result.
- Risk: large instructor dashboards could introduce per-learner/per-objective query loops.
  Mitigation: require set-based provider queries and performance-oriented tests.

## 14. Open Questions & Assumptions

### Open Questions

- None.

### Assumptions

- `learning_states.aoa` is the LKT-AOA proficiency score to display.
- `learning_states.confidence` is a separate raw `0.0..1.0` confidence signal and must not be
  encoded into the score, proficiency label, or confidence display bucket in this work.
- Confidence Low/Medium/High bucketing is owned by future UI work.
- Direct LKT-AOA learning-objective results require at least three attempts on that objective.
- Page, container, and course learner results require at least three total attempts across available
  contributing learning-objective states.
- Page, container, and course scores are unweighted arithmetic means of available learning-objective
  AOA scores.
- An unattempted learning objective in a scope is omitted from the mean and contributes zero attempts
  to the scope threshold.
- A learning objective appearing on multiple pages contributes the same Section-wide state to each
  applicable page and ancestor container.
- Objectives attached directly to page Revisions do not establish page proficiency membership.
- Authoring Insights remains descriptive analytics and does not use this proficiency read path.

## 15. QA Plan

- Automated validation:
  - Unit-test canonical estimate labeling, missing-state behavior, zero-score behavior, raw
    confidence value propagation, and provider dispatch.
  - Integration-test naive parity against existing Metrics outputs.
  - Integration-test LKT-AOA direct objective reads from `learning_states`.
  - Test parent objective, page, container, course, learner, and class aggregation rules.
  - Test SectionResource post-processing for objective and page `related_activities`, including SRD
    update or invalidation behavior.
  - Test dashboard oracles and scenario assertions for both `:naive` and `:lkt_aoa` Sections.
  - Add query-count or equivalent tests proving set-based reads and no delivery-time revision lookup
    for page/container/course membership.
- Manual validation:
  - Exercise a `:naive` Section and confirm existing proficiency screens remain semantically
    unchanged.
  - Exercise an `:lkt_aoa` Section with materialized learner state and confirm objective and scope
    values use AOA rather than naive summary formulas.
  - Inspect dashboard payloads and CSV exports where proficiency values are surfaced.

## 16. Definition of Done

- [x] PRD sections complete
- [x] requirements.yml captured and valid
- [x] validation passes
