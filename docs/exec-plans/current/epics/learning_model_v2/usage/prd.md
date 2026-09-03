# Learning Model: Proficiency Reads and Usage - Product Requirements Document

## 1. Overview
Provide one model-aware proficiency read boundary for learner and instructor experiences. Every proficiency result is selected from the Section's persisted learning model, while existing `:naive` Sections retain their current behavior and `:lkt_aoa` Sections consume materialized learning state without scanning attempt history.

## 2. Background & Problem Statement
Torus proficiency is currently exposed through `Oli.Delivery.Metrics` in several incompatible shapes and is calculated directly in some consumers. Those paths assume the naive `ResourceSummary` formula, which prevents safe use of the LKT-AOA state introduced by the preceding learning-model work items. Page and container views also need a precise, efficient mapping from Section-pinned activities to learning objectives. Without a canonical estimate, model-specific providers, and coherent SectionResource projections, consumers can mix models, confuse missing evidence with zero proficiency, perform costly query loops, or display approximate values where LKT-AOA provides actual aggregates.

## 3. Goals & Non-Goals
### Goals
- Route proficiency reads through explicit naive and LKT-AOA providers selected solely by the persisted Section model.
- Give new consumers a consistent estimate containing score, label, confidence, evidence counts, and model provenance while preserving existing Metrics contracts during migration.
- Derive objective, page, container, course, learner, and class results with the model-specific eligibility and aggregation rules.
- Make page-to-objective scope membership available from coherent, Section-pinned `SectionResourceDepot` data without delivery-time database queries.
- Integrate learner views, instructor dashboard oracles, snapshots, exports, recommendations, and scenario assertions without presentation-layer model branching.
- Demonstrate naive parity and scalable, set-based LKT-AOA reads through automated coverage and telemetry.

### Non-Goals
- Changing descriptive Authoring Insights analytics or redefining its relative-difficulty heuristic.
- Training, estimating, or editing learning-model parameters.
- Persisting page-, container-, course-, parent-objective-, or class-level proficiency aggregates.
- Allowing callers or presentation components to override a Section's selected model.
- Adding a normal product interface for switching learning models or designing a confidence UI.
- Replacing the existing `ContainedObjective` projection for its current consumers.

## 4. Users & Use Cases
- Learners: see proficiency for objectives, lessons, pages, containers, reviews, and dashboards calculated with their Section's selected model.
- Instructors: inspect learner, objective, page, container, and class proficiency with accurate numeric aggregates, distributions, confidence, and coverage where supported.
- Learning engineers and researchers: rely on model provenance and evidence fields to interpret LKT-AOA results without changing descriptive Authoring Insights.
- Developers and operators: use one stable boundary, scalable queries, coherent caches, and scenario assertions to evolve and diagnose proficiency behavior.

## 5. UX / UI Requirements
- Existing label-only experiences retain their established visible labels and empty-state behavior for naive Sections.
- Missing or insufficient evidence is presented as unavailable/not enough information and is never displayed as numeric zero.
- A rendered experience must use one provider consistently; unavailable LKT-AOA data must not silently appear as naive proficiency.
- Dashboard summaries and CSV exports use actual numeric LKT-AOA aggregates rather than numbers reconstructed from category counts.
- Any future display of confidence requires an approved presentation and accessibility contract; this work only supplies the data.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Instructor and bulk reads must be set-based and avoid per-learner and per-objective query loops.
- LKT-AOA direct-objective reads must use materialized `learning_state` and must not scan historical attempts.
- Page, container, and course membership resolution must use in-memory SRD records and perform no delivery-time database query.
- Database projections and distributed `SectionResourceDepot` entries must be coherent after successful post-processing.
- Telemetry must expose bounded latency, result availability, provider/model, and bulk-size signals without learner-, attempt-, or raw-content identifiers.
- Existing authorization, Section tenancy, publication pinning, privacy, and immutable published-content boundaries remain unchanged.

## 9. Data, Interfaces & Dependencies
- Depends on persisted Project/Section model selection and Revision parameters from `docs/exec-plans/current/epics/learning_model_v2/data_model/`.
- Depends on materialized LKT-AOA `learning_state` from `docs/exec-plans/current/epics/learning_model_v2/core_impl/`.
- Introduces a model-neutral `Oli.Delivery.Proficiency.Estimate` with Section, learner, objective, score, label, confidence, attempt count, unique activity-part count, and model version.
- Keeps `Oli.Delivery.Metrics` as a compatibility facade and places model-specific behavior behind `Oli.Delivery.Proficiency.Naive` and `Oli.Delivery.Proficiency.LktAoa`.
- Extends `SectionResource.related_activities`: objective records hold targeting activity IDs; page records hold embedded activity IDs from Section-pinned Revisions; other record types remain empty absent another contract.
- Adds a versioned Section-level marker for JIT SectionResource migration so the depot can distinguish an unprocessed legacy Section from one whose page projections were successfully populated, including valid empty arrays.
- Uses the SectionResource hierarchy and the intersection of page and objective activity IDs to resolve distinct objective membership for page, container, and course scopes.
- Changes instructor-oracle payloads and implementation versions. Deployment requires an application restart, which clears affected in-memory dashboard caches before the new contracts serve traffic.

## 10. Repository & Platform Considerations
- Backend domain logic belongs under `lib/oli/delivery/`; existing web and presentation consumers should adapt to provider results without owning model dispatch.
- Preserve the resource/revision and publication model by resolving Section-pinned page and activity Revisions, never latest authoring revisions.
- Extend existing Section post-processing paths for creation, template creation, publication update, duplication/remix, and applicable repair or migration workflows.
- Use ExUnit for provider, aggregation, post-processing, oracle, cache, and compatibility tests; use `Oli.Scenarios` for authoring-to-delivery workflow verification without fixtures, factories, or mocks.
- Implementation review must include the repository's security, performance, Elixir, and requirements guidance; UI guidance applies only if presentation behavior is added.
- Jira issue [MER-5846](https://eliterate.atlassian.net/browse/MER-5846) is the linked execution record for the broader LKT-AOA implementation.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

Existing Sections remain `:naive`. LKT-AOA reads activate only for Sections already persisted as `:lkt_aoa` after their materialized write path and required scope projections are available. Existing SectionResources are upgraded just in time through `SectionResourceDepot` before their depot table is loaded; no full deployment backfill is allowed. Rollout must preserve naive results, increment changed oracle implementation versions, and restart the application so old in-memory caches are gone. Section model migration and its cache lifecycle are outside this work item. There is no fallback from unavailable LKT-AOA data to naive calculations.

## 12. Telemetry & Success Metrics
- Emit bounded provider-read observations suitable for AppSignal analysis, including model version, scope type, duration, result counts, unavailable counts, and query scaling, without learner or attempt identifiers.
- Success means automated parity coverage finds no naive calculation or return-contract regressions.
- Success means LKT-AOA objective reads use materialized state and bulk instructor reads exhibit bounded query counts as learner and objective counts increase.
- Success means all inventoried proficiency consumers dispatch through the facade/provider boundary and no direct naive formula remains outside the naive provider or explicitly out-of-scope descriptive analytics.
- Success means dashboard and export paths consume actual numeric LKT-AOA aggregates and report confidence/coverage without changing proficiency scores or labels.

## 13. Risks & Mitigations
- Naive compatibility regressions: characterize current thresholds, minimum evidence, shapes, and representative outputs before replacing internals; retain facade adapters and parity tests.
- Mixed-model or silent fallback results: make Section the sole dispatch authority and return explicit unavailable results when LKT-AOA dependencies are incomplete.
- Stale or divergent scope membership: update database projections in bulk and update or invalidate distributed SRD entries as part of every relevant post-processing workflow.
- N+1 queries and high dashboard latency: resolve membership in memory, bulk-read learner state, use set-based aggregation, and enforce query-count tests plus telemetry.
- Incorrect objective membership: use only Section-pinned activity relationships, ignore direct page-objective attachments, and deduplicate objective IDs.
- Cache incompatibility after payload changes: increment oracle versions and require the rollout restart to clear old in-memory cache entries.
- Misleading confidence presentation: keep confidence and coverage separate from score and label, and defer visible confidence treatment until UX is approved.

## 14. Open Questions & Assumptions
### Open Questions
N/A

### Assumptions
- The preceding data-model and core-implementation work items provide valid persisted model selection, Revision parameters, and materialized LKT-AOA state before this work is enabled.
- Existing Metrics return shapes are compatibility contracts unless a later design explicitly deprecates them.
- Parent-objective scores are weighted by child `attempt_count`; the parent displays not-enough-information only when total attempts across all effective children are fewer than three.
- A Section-level integer `section_resource_migration_version` starts below the new current version for legacy Sections and advances only after their JIT SectionResource migration commits successfully.
- `get_objectives_and_subobjectives/2` retains its current label/distribution contract unless another in-scope consumer requires more data.
- Confidence and coverage UI is a separate follow-up; this work adds no presentation behavior for those signals.
- Semantic equivalence is acceptable where byte-for-byte naive equality is not meaningful, such as unordered map data.
- No new end-user controls, database table for contained page objectives, or persisted aggregate-state records are required.

## 15. QA Plan
- Automated validation:
  - Add focused ExUnit coverage for provider dispatch, canonical estimates, thresholds, missing versus zero, parent rollups, scope aggregation, and compatibility adapters.
  - Add query-count tests proving state and instructor reads are set-based and scope membership is SRD-only at delivery time.
  - Cover Section post-processing and distributed depot coherence across content establishment and update paths.
  - Test oracle versioning, rollout restart assumptions, numeric dashboard/export propagation, and removal of direct naive calculations.
  - Add `Oli.Scenarios` coverage for representative naive and LKT-AOA authoring, publishing, section, learner-attempt, and proficiency-assertion workflows.
  - Run targeted `mix test`, `mix format`, scenario validation/execution, and broader regression suites in proportion to affected consumers.
- Manual validation:
  - Compare representative learner and instructor views for naive Sections before and after migration.
  - Verify unavailable LKT-AOA scope data is explicit and never rendered using a naive fallback.
  - Inspect dashboard, summary, CSV, and recommendation outputs for actual numeric LKT-AOA values and consistent labels.
  - Confirm telemetry and AppSignal-visible metadata are useful and contain no learner-level or attempt-level identifiers.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
- [ ] All inventoried proficiency consumers use the model-aware boundary or are explicitly documented as descriptive analytics.
- [ ] Naive parity, LKT-AOA correctness, SRD coherence, set-based query behavior, dashboard integration, and both-model scenarios pass.
- [ ] Required security, performance, Elixir, and requirements reviews have no unresolved blocking findings.
