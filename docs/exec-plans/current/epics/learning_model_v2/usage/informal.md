# Learning Model: Proficiency Reads and Usage

This work item introduces model-aware proficiency reads and integrates them with learner and instructor consumers. It is the third of three implementation chunks derived from `docs/exec-plans/current/epics/learning_model_v2/informal.md`.

It depends on:

- Model selection and Revision parameters from `docs/exec-plans/current/epics/learning_model_v2/data_model/informal.md`.
- Materialized LKT-AOA state from `docs/exec-plans/current/epics/learning_model_v2/core_impl/informal.md`.

The intended outcome is that every proficiency consumer uses the Section's selected model while existing `:naive` sections retain their current behavior.

## Scope

This chunk includes:

- A model-neutral proficiency read boundary.
- Naive and LKT-AOA providers.
- Compatibility adapters for existing Metrics consumers.
- Objective and learner aggregation.
- Page activity-membership projection into `SectionResource.related_activities` and SRD-backed scope resolution.
- Instructor-dashboard oracle and cache integration.
- Confidence and coverage in new read contracts.
- Scenario coverage and naive-model parity verification.

It does not change descriptive Authoring Insights analytics or train learning-model parameters.

## Current naive proficiency

`Oli.Delivery.Metrics` in `lib/oli/delivery/metrics.ex` is the primary current proficiency boundary. The naive model reads `Oli.Analytics.Summary.ResourceSummary` and uses first-attempt counts:

```text
(first_attempts_correct + 0.2 * incorrect_first_attempts) / first_attempts
```

It reports `"Not enough data"` for fewer than three first attempts. Its current boundaries classify scores at or below `0.4` as Low, scores above `0.4` through `0.8` as Medium, and scores above `0.8` as High.

The current Metrics API includes:

```text
proficiency_for_student_per_learning_objective/3
raw_proficiency_per_learning_objective/2
proficiency_per_container/2
proficiency_per_student_across/2
proficiency_for_student_per_container/3
proficiency_for_student_per_page/2
proficiency_per_student_for_page/2
proficiency_per_page/2
proficiency_per_student_for_objective/3
objectives_proficiency/3
student_proficiency_for_objective/2
proficiency_range/2
```

These functions return several shapes, including raw tuples, label strings, nested maps, and student rows. That inconsistency must not leak into the new model provider contract.

## Model-aware facade

Keep `Oli.Delivery.Metrics` as a compatibility facade for existing callers, but move model-specific queries and calculations into explicit providers:

```text
Oli.Delivery.Proficiency
Oli.Delivery.Proficiency.Estimate
Oli.Delivery.Proficiency.Naive
Oli.Delivery.Proficiency.LktAoa
```

Dispatch uses the persisted Section value:

```elixir
def proficiency_per_student_for_objective(
      %Section{learning_model_version: :naive} = section,
      objective_ids,
      opts
    ),
    do: Proficiency.Naive.proficiency_per_student_for_objective(section, objective_ids, opts)

def proficiency_per_student_for_objective(
      %Section{learning_model_version: :lkt_aoa} = section,
      objective_ids,
      opts
    ),
    do: Proficiency.LktAoa.proficiency_per_student_for_objective(section, objective_ids, opts)
```

Callers must not pass an independent model option. The Section is the source of truth.

Several existing functions accept only `section_id`. Their preferred overload accepts `%Section{}` so dispatch requires no extra query. Temporary integer-ID clauses may load the Section and delegate for backward compatibility. Internal callers that already have a Section must pass it directly.

The `analytics_version` field is unrelated and must not participate in this dispatch.

## Canonical estimate

New code consumes a model-neutral structure:

```text
Proficiency.Estimate
  section_id
  user_id
  learning_objective_id
  score                       # 0.0..1.0 or nil
  label                       # low, medium, high, not_enough_information
  confidence                  # 0.0..1.0 or nil
  attempt_count
  unique_activity_part_count
  learning_model_version
```

The naive provider populates fields available from `ResourceSummary` and leaves unsupported confidence fields unset. The LKT-AOA provider populates the complete structure from `learning_state`.

Existing Metrics functions adapt canonical estimates into their established return shapes during migration. New consumers should use estimates directly when they need score, confidence, evidence counts, or model provenance.

`raw_proficiency_per_learning_objective/2` is coupled to naive `ResourceSummary` tuples. It must remain a `Naive` implementation detail or be deprecated; it must not return a different tuple shape for LKT-AOA.

Bucketing belongs to each provider:

- `Naive` preserves existing thresholds and its three-first-attempt rule exactly.
- `LktAoa` classifies AOA below `0.4` as Low, `0.4` through `0.8` as Medium, and above `0.8` as High. A direct LO requires three attempts on that LO. Page, container, and course aggregates require three total attempts across the LOs contributing to that learner's scope result.

The shared current `proficiency_range/2` cannot determine both models from a score and naive attempt count alone.

## LKT-AOA reads

For a direct LO/sub-objective estimate, query `learning_state` by `(section_id, user_id, learning_objective_id)` and return stored AOA and confidence. Historical attempts are never read to answer this query.

A missing state produces `not_enough_information`, not a numeric zero. Zero can be a valid model score and must remain distinct from no evidence.

A direct LO returns `not_enough_information` until its `learning_state.attempt_count` reaches three. Parent-LO aggregation follows its separately defined sub-objective eligibility rule. Page, container, and course aggregation use the scope-wide three-attempt rule defined below; an unattempted LO in one of those scopes does not suppress the entire scope result.

### Parent LO aggregation

For a parent LO, resolve its effective sub-objectives and aggregate learner states using the parent-LO weighting and coverage rules from the LKT-AOA technical definition. Parent results are derived from child LOs; they are not independently persisted merely to make reads easier. This parent/sub-objective rollup is distinct from the unweighted page, container, and course aggregation defined below.

Instructor-level reads must aggregate learners and objectives in set-based queries. They must not issue one query per learner or per objective.

The provider should return both:

- Actual numeric aggregate values when defined.
- Categorical distributions for presentation and compatibility.

Confidence and coverage remain separate from proficiency. They must not be encoded by modifying the proficiency score or bucket label.

## Read integration inventory

The major consumers found in the repository are:

- Student lesson, prologue, and review views for attached objectives.
- Student dashboard page and container proficiency.
- Classic instructor dashboard page, container, and learner proficiency.
- Learning-objective page elements.
- Expanded objective components and individual-student distributions.
- `Oli.Delivery.Sections.get_objectives_and_subobjectives/2`.
- Intelligent-dashboard proficiency oracles.
- Dashboard snapshots, student support, challenging objectives, summaries, CSV exports, and recommendations downstream of those oracles.
- Scenario proficiency assertions.

Presentation components should not branch on `learning_model_version`. The provider/facade returns the selected model's data in the contract expected by the consumer.

## Direct calculations that must be removed

`Oli.InstructorDashboard.Oracles.ProgressProficiency` in `lib/oli/instructor_dashboard/oracles/progress_proficiency.ex` bypasses Metrics and repeats the naive `ResourceSummary` formula. It must delegate to the model-aware facade.

`lib/oli/scenarios/directives/assert/proficiency_assertion.ex` also reads raw naive counts and reconstructs proficiency. Scenario assertions must consume canonical estimates so the same directive can verify either model.

Other consumers that merely format or classify a supplied proficiency value do not need their own dispatch logic.

## Authoring Insights is not proficiency usage

Authoring Insights reads aggregate `ResourceSummary` data and displays:

- Attempt count.
- First-attempt count.
- First-attempt correct percentage.
- Eventually-correct percentage.
- Relative difficulty.

It does not calculate learner proficiency, apply proficiency buckets, or read `learning_state`. Its `relative_difficulty` is an existing heuristic based on correctness and hints; it is not the learned activity-part `beta_difficulty` parameter.

Authoring Insights remains descriptive analytics and is outside naive/LKT-AOA read dispatch unless a separate product requirement explicitly adds model proficiency there.

## Page, container, and course aggregation

`learning_state` is keyed by learning objective, so page-, container-, and course-scoped proficiency is derived from the learner's current Section-wide LO states. These scope values are read-time projections and are not independently persisted.

### Scope membership

An LO belongs to a page only when it is attached to an activity embedded in that page. An objective attached directly to the page Revision does not establish page membership for proficiency and must be ignored by this calculation.

The Section post-processing projection resolves embedded activity IDs from the page Revision pinned to the Section and objective attachments from the Section-pinned activity Revisions. It must not use the latest authoring revisions. At delivery time, the SRD-backed projection is the source of both relationships; deduplicate the resulting LO resource IDs before reading learner state so multiple embedded activities targeting the same LO do not cause that LO to appear more than once in the average.

An LO belongs to a container when it belongs to any descendant page in that container's scope. Course scope uses the root container and therefore includes the distinct union of LOs across the course.

### SectionResource `related_activities` projection

The key delivery optimization is to extend the meaning of the existing `SectionResource.related_activities` field to page SectionResources:

- On an objective SectionResource, `related_activities` remains the activity resource IDs that target that LO.
- On a page SectionResource, `related_activities` is the activity resource IDs embedded in that page.
- On other SectionResource types, the field remains empty unless a separate contract is introduced later.

The field therefore has one general meaning—activities related to this Section resource—with a type-specific source. The `SectionResource` schema documentation must describe both supported meanings rather than saying that the field is meaningful only for objectives.

Extend the existing `:related_activities` Section post-processing action in `Oli.Delivery.Sections.PostProcessing` so it populates both record types in bulk:

1. Preserve the current objective projection, which reverses activity objective attachments into `objective SectionResource.related_activities`.
2. For every page SectionResource, resolve its Section-pinned page Revision and copy that Revision's `activity_refs` into `page SectionResource.related_activities`.
3. Store distinct activity resource IDs and use an empty array for pages with no embedded activities.
4. Do not inspect or incorporate the page Revision's direct objective attachments.

This post-processing must run anywhere Section-pinned content can be established or changed, including Section and template creation, publication updates, duplication/remix paths, and any repair or migration that changes pinned Revisions. Updating the database rows is not sufficient: the operation must update or invalidate the distributed `SectionResourceDepot` entries so every node observes the new arrays. The database projection and the SRD must not diverge after post-processing succeeds.

Once populated, page/container/course membership requires no delivery-time database query and no new `ContainedPageObjective` table. Both sides of the relationship are already present in the SRD:

```text
objective SectionResource.related_activities = activities targeting the LO
page SectionResource.related_activities      = activities embedded in the page
```

An LO belongs to a page when the intersection of those two activity-ID sets is non-empty. For efficient bulk calculation, build an in-memory `activity_id -> learning_objective_ids` index once from the objective SectionResources, then map each page's `related_activities` through that index and deduplicate the resulting LO IDs.

Container and course membership use the hierarchy already available from the SRD: collect the applicable descendant page SectionResources and take the distinct union of their derived LO IDs. Direct page-objective attachments never enter this path, so they cannot accidentally affect proficiency scope.

The existing `Oli.Delivery.Sections.ContainedObjective` projection remains available to its current consumers, but it is not the authority for LKT-AOA page/container/course membership because its broader contract currently includes objectives attached directly to pages.

### Learner scope calculation

For a learner and one page, container, or course scope:

1. Resolve the distinct LO IDs in that scope.
2. Bulk-read the learner's `learning_state` rows for those IDs.
3. Sum `attempt_count` across the returned states.
4. If the total is fewer than three, return `not_enough_information`.
5. Otherwise, return the arithmetic mean of the available `aoa` scores.

There is no weighting. Attempt count, unique activity-part count, confidence, and the number of times an LO is referenced do not change an LO's contribution to the scope score. Every contributing LO has equal weight.

An LO with no `learning_state` has no score and is omitted from the arithmetic mean. It also contributes zero to the scope attempt total. It does not block display when other contributing LO states collectively have at least three attempts. This preserves the existing page/container concept of requiring three attempts across the scope rather than requiring three attempts on every LO in that scope.

An LO appearing on multiple pages contributes the same current Section-wide learner state to every applicable page. It likewise contributes once to each applicable ancestor container. There is no page-local copy of LO proficiency and no attempt filtering based on the page where the evidence originally occurred.

For instructor/class scope results, first calculate the defined learner scope results using the rules above, then take an unweighted arithmetic mean across learners with a defined score. Learners returning `not_enough_information` are excluded from that numeric average and remain represented as not-enough-information in categorical distributions. The payload should report how many learners contributed to the numeric result.

Until page `SectionResource.related_activities` is populated and guaranteed coherent in the SRD, LKT-AOA page, container, and course consumers must explicitly return unavailable rather than silently using the naive formula or the broader existing contained-objective projection.

## Dashboard oracles and caches

`Oli.InstructorDashboard.Oracles.ObjectivesProficiency` already delegates to Metrics, but it should pass the Section instead of only `section_id`. `ProgressProficiency` must stop querying `ResourceSummary` directly.

Current downstream projections accept proficiency in `0.0..1.0` and categorical objective distributions. Those shapes can remain compatible. Oracle payloads must add confidence, coverage, and actual numeric objective aggregates as explicit fields.

Current summary projections reconstruct an approximate numeric "Average Class Proficiency" from category counts. They are inconsistent:

- `lib/oli/instructor_dashboard/data_snapshot/projections/summary.ex` and CSV helpers use Low/Medium/High = 20/60/100.
- `lib/oli/instructor_dashboard/data_snapshot/projections/summary/projector.ex` uses 30/60/90.

LKT-AOA provides actual numeric values. Dashboard cards and CSV exports must consume those values instead of converting to labels and approximating a number. Naive behavior may remain unchanged for compatibility.

Oracle implementation versions must be incremented when calculation or payload shape changes. Cached dashboard snapshots must be invalidated or rebuilt if a Section's model version is changed through an authorized migration.

## Rollout behavior

Existing Sections remain `:naive` and must produce byte-for-byte or semantically equivalent results through the new facade.

LKT-AOA reads are enabled only for Sections with `learning_model_version: :lkt_aoa` and only after their materialized state write path is active.

A Section must never mix providers within one rendered view. If required LKT-AOA data or a required scope-membership projection is unavailable, the result is explicitly unavailable rather than a fallback to naive proficiency.

Confidence is a new signal. Existing label-only consumers can migrate incrementally, but any new UI that displays confidence needs an agreed presentation contract and UX design.

## Verification boundary

This chunk is complete when tests demonstrate:

- Naive Sections retain current calculations, thresholds, and return contracts.
- LKT-AOA objective reads use `learning_state` and do not scan attempts.
- Missing state is distinct from a real score of zero.
- Parent LO aggregation follows its documented sub-objective weighting and coverage policy.
- Page, container, and course learner scores are unweighted arithmetic means of distinct, available Section-wide LO states.
- Page, container, and course learner scores remain `not_enough_information` until their contributing states contain at least three total attempts.
- An unattempted LO does not suppress an otherwise eligible page, container, or course result.
- An LO appearing on multiple pages contributes the same Section-wide state once to every applicable page and ancestor container.
- Objectives attached directly to page Revisions do not contribute to page, container, or course proficiency membership.
- Objective and page SectionResources contain their respective type-specific `related_activities` projections from Section-pinned revisions.
- Related-activity post-processing updates or invalidates the distributed SRD after changing the database projection.
- Page and container membership is calculated entirely from SRD records, produces consistent deduplicated LO sets, and executes no delivery-time database query.
- Section-level reads are set-based and avoid per-learner/per-objective query loops.
- Every direct naive formula outside the `Naive` provider has been removed or intentionally classified as descriptive analytics.
- Dashboard oracles dispatch by Section model and cache versions are updated.
- Numeric LKT-AOA aggregates reach dashboards and exports without label-based reconstruction.
- Scenario assertions cover both `:naive` and `:lkt_aoa` Sections.
- Missing page/container membership infrastructure cannot silently fall back to naive proficiency.
