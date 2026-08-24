# Native Experiment Workflow

This guide follows a native Torus experiment from research planning through authoring, delivery,
completion, archival, and analysis. It is intended for researchers and course authors working
together on weighted-random or Thompson Sampling experiments.

Related references:

- [Native Experiment Data Guide](README.md) explains the overall research-data model.
- [Experiment Data and Key Reference](data-reference.md) documents S3 JSON, ClickHouse columns,
  event records, and key formats.
- [ClickHouse Query Cookbook](queries.md) provides scoped analysis examples.
- [Native Experiment Glossary](glossary.md) defines authoring, lifecycle, data, and policy terms.

## Workflow at a glance

```text
Plan
  → author a Decision Point and conditions
  → publish the content to sections
  → create a draft experiment
  → configure policy, participation, and interventions
  → validate and start
  → monitor assignments, exposures, outcomes, and rewards
  → pause/resume if needed
  → complete
  → analyze and report
  → archive when the experiment no longer needs to appear in active management
```

## 1. Plan the experiment

Before changing course content, write down the research contract:

- research question and hypothesis;
- primary and secondary outcomes;
- unit of assignment (currently section enrollment);
- assignment scope
- participating sections and expected sample size;
- condition labels and stable condition codes;
- experiment start, stopping, exclusion criteria, and the planned analytical treatment of
  repeated attempts;
- whether allocation is fixed weighted random or adaptive Thompson Sampling;
- for Thompson Sampling, the assessment page, success threshold, priors, warm-up period, and
  guardrails;
- authorized researchers, approved data fields, retention expectations, and reporting plan.

Choose the [assignment scope](glossary.md#assignment-scope) deliberately:

| Scope              | Meaning                                                                                         | Supported algorithms                  |
| ------------------ | ----------------------------------------------------------------------------------------------- | ------------------------------------- |
| intervention       | An enrollment is assigned independently at each experiment placement.                           | Weighted random and Thompson Sampling |
| section enrollment | An enrollment keeps one condition across all placements for the experiment within that section. | Weighted random only                  |

The enrollment is the pseudonymous participant identifier. The same user in two sections is two
analytical participants.

### Choose Weighted Random when

- allocation proportions should remain fixed or manually adjusted;
- every active condition has a configured relative weight;
- no outcome-driven policy adaptation is needed;
- the study design requires a conventional fixed allocation.

Weights are relative and do not need to sum to one. `1 / 1` is an even two-condition allocation;
`2 / 1` is approximately a two-to-one allocation. Weighted-random assignments are sticky: once an
enrollment is assigned within the configured scope, Torus reuses that assignment.

### Choose Thompson Sampling when

- allocation should adapt to observed binary reward evidence;
- each intervention can be tied to a scored assessment page;
- the study design allows adaptive allocation and its resulting nonuniform sample sizes;
- priors and traffic guardrails are specified before activation.

Thompson Sampling uses beta priors. A reward at or above the configured threshold is `1.0`; a
reward below it is `0.0`. A missing reward is `NULL`, not zero. See
[Weighted random and Thompson Sampling](README.md#weighted-random-and-thompson-sampling) for the
data-level differences.

## 2. Author the Decision Point

In the course-author workspace, open **Experiments**. Native experiments depend on a
[Decision Point](glossary.md#decision-point), which is an Alternatives Group configured for
experiment-controlled delivery.

1. Select **New Decision Point**.
2. Give the Decision Point a meaningful title.
3. Add at least two conditions/options.
4. Place the Decision Point on every page where the intervention should occur.
5. Author the content for each option at the placed Decision Point.
6. For Thompson Sampling, identify each placement by its page and Alternatives element ID, then
   identify the scored page that will provide reward evidence.

Condition codes are analytical identities. Use stable, non-sensitive codes such as `control` and
`worked_example`; do not encode learner information in them. Labels can be more descriptive, but
research scripts should group by the stable code.

When an experiment starts, Torus disables editing that would remove or repurpose its Decision Point
options. This preserves each condition's meaning for the life of the experiment and subsequent
analysis.

### Decision Point ownership and default behavior

Only one experiment can be active for a given Decision Point at a time. Torus prevents a second
experiment that uses the same Decision Point from becoming active until the current experiment is
no longer active.

When no experiment is active for a Decision Point, Torus selects its default condition. The default
is always the first condition in the Decision Point.

If a later experiment using that Decision Point is started, each learner receives a new sticky
assignment for the new experiment. Assignments from an earlier experiment are not reused because
the experiment itself is part of assignment identity. The new assignment is then reused according
to that experiment's configured assignment scope.

## 3. Publish the content to sections

Experiments associate learner content according to the Torus publication model. Learners receive
content according to the currently pinned publication for their section and experiment analytics
associate outcomes with the content revisions at the time of each evaluated attempt.

Before activation:

1. Publish the project containing the Decision Point and intervention pages.
2. Update that publication in every intended participating section.
3. Confirm the Decision Point is present in each section's published content.
4. Confirm every active condition maps to an option in the published Decision Point.
5. For Thompson Sampling, confirm every intervention page and scored assessment page is included
   in the section publication.

Activation fails when the selected Alternatives resource is missing from a participating section,
is not experiment-controlled, has fewer than two active conditions, has no positive active weight,
or has condition-to-option mappings that do not match published section content.

## 4. Create the draft experiment

From the course-author **Experiments** page:

1. Select **Create Experiment**.
2. Choose **Weighted random** or **Thompson Sampling** as the assignment policy.
3. Enter a researcher-readable name.
4. Enter a short, researcher-readable slug. Treat this as a label, not a portable experiment
   identifier. It is unique only within the current project in the current Torus instance.
5. Select the Decision Point.
6. Select **Create**.

The experiment begins in `draft`. Creation also gives it a stable UUID. Use `experiment_uuid` in
cross-environment exports when available; use `experiment_id` for joins within the current Torus
database. Use the experiment slug for readable labels and filtering only; the same slug can exist
in another project or Torus instance.

## 5. Configure the draft

Draft is the only state in which the experiment's structural configuration is fully editable.
Review the following sections before starting.

### Participating sections

Select **Participating sections**, choose the eligible course sections, and save. Section
participation can be changed while the experiment is `draft`, `active`, or `paused`, but becomes
read-only after completion.

Only include sections covered by the research plan and data-access approval. Adding sections later
changes the recruitment population and should be documented.

### Conditions

For every condition:

- verify its stable code;
- set a readable label;
- map it to the intended Decision Point option;
- mark it active or inactive;
- set its allocation weight where editable.

Draft experiments require at least two active conditions and a positive total active weight. While
an experiment is active or paused, condition availability can be changed. Existing assignments are
sticky: making a condition unavailable does not rewrite learners already assigned to it.

Weighted-random weights may also be adjusted while active or paused. Treat any allocation change as
a protocol amendment and record its time, rationale, and expected analytical handling.

### Weighted-random configuration

Choose the condition assignment scope:

- **Independent at each intervention** (`intervention`); or
- **Same condition within each participating course section** (`section_enrollment`).

Verify each condition's relative weight. Weighted random does not require assessment bindings and
does not create policy reward evidence from evaluated attempts.

### Thompson Sampling configuration

Thompson Sampling always uses intervention scope. Configure:

- **Prior alpha** and **prior beta**, each between `0.0001` and `1000`;
- **Warm-up assignments**, the count allocated using warm-up weights before adaptive sampling;
- **Max condition share**, the largest allowed traffic share for one condition;
- optional **Fixed-control allocation**;
- **Imbalance warning threshold**;
- each **Intervention page** and **Placement element ID**;
- each intervention's **Scored page** and **Success threshold** from `0` to `1`.

Every Thompson intervention must have an assessment binding before activation. The current reward
source is the assessment page's normalized score. When the scored resource attempt completes,
Torus compares its normalized score with the threshold and records an explicit binary reward.

## 6. Preflight before starting

Use this checklist with both the course author and researcher:

- [ ] The research protocol and participating sections are approved.
- [ ] The project is published and intended sections have the current section publication.
- [ ] Every condition maps to the correct published option.
- [ ] At least two conditions are active and total active weight is positive.
- [ ] Assignment scope matches the research design.
- [ ] Thompson priors and guardrails are documented.
- [ ] Every Thompson intervention has a valid scored-page binding and threshold.
- [ ] Test learners can render each condition without missing content.
- [ ] Page-view, attempt, and—where applicable—reward events reach the analytics pipeline.
- [ ] The analysis uses `enrollment_id` and has explicit time and tenant scopes.

Selecting **Start** runs activation validation. Fix validation errors instead of bypassing them.

## 7. Operate the experiment

An active experiment participates in delivery assignment. At a high level:

1. A learner enters an eligible participating section.
2. Torus resolves the Decision Point from the section publication.
3. Torus creates or reuses a sticky assignment for the configured scope.
4. The selected condition determines which option is realized.
5. Rendering records exposure evidence.
6. Supported media interactions can carry assignment attribution.
7. Evaluated attempts create raw outcome events; selected-branch attempts also carry experiment
   outcome attribution.
8. Thompson assessment completion creates explicit reward evidence and updates policy state.

See [Event-to-record mapping](data-reference.md#event-to-record-mapping) for the exact S3 and
ClickHouse records created at each step.

### Monitor while active

Monitor operational health separately from research results:

- participating-section and published-content consistency;
- evidenced assignments and exposures by condition;
- missing or delayed xAPI ingestion;
- attributed outcomes versus the complete raw activity stream;
- Thompson rewards, missing rewards, and reward latency;
- Thompson posterior state and guardrail status;
- unexpected condition imbalance.

The Thompson policy report displays observed assignment and reward state, priors, posterior values,
and guardrail status. Its estimated success probability is a posterior summary, not a prediction of
the next learner's assignment.

Use the [query cookbook](queries.md) for bounded monitoring queries. ClickHouse assignment counts
are evidenced assignments, not a complete allocation audit; use the transactional assignment store
when completeness is required.

## 8. Pause and resume

Select **Pause** to move an active experiment to `paused`. The policy snapshot remains available.
Use a pause for a documented operational or protocol reason, such as content repair, data-quality
investigation, or planned enrollment suspension.

A paused experiment can be resumed with **Resume** or ended with **Complete**. Resume does not rerun
the draft activation validator, so manually repeat the relevant preflight checks—especially section
publication, condition availability, and weights—before resuming. Record pause and resume timestamps
in the analysis notes because exposure and outcome activity may not be uniform across the pause
boundary.

Do not interpret pause as deleting prior assignments or analytics. Existing transactional and
analytics records remain available.

## 9. Complete the experiment

An active or paused experiment can be completed. Completion:

- ends experiment assignment activity;
- records the experiment end time;
- freezes the final policy snapshot;
- makes structural configuration and section participation read-only;
- preserves assignments, evidence, S3 statements, and ClickHouse rows for analysis.

Before selecting **Complete**:

1. Confirm the stopping rule has been met.
2. Record the analysis cutoff timestamp.
3. Check ingestion health and known missing evidence.
4. Capture the final Thompson policy snapshot when applicable.
5. Confirm no planned participating sections were accidentally omitted.

Completion is not archival and does not remove the experiment from the management list.

## 10. Archive the experiment

A `draft` experiment can be archived if it will not run. A `completed` experiment can be archived
after operational work is finished. The standard authoring UI offers Archive only for draft and
completed experiments, so active or paused experiments follow the normal **Complete**, then
**Archive** workflow. The domain lifecycle also accepts direct archival from active or paused state
for authorized non-UI callers; that exceptional path skips completion and does not set
`ended_at`, so it should be reserved for an explicitly documented operational need.

Archival removes the experiment from active use and hides it from the default experiment list. Use
**Show archived experiments** to view it again. Archival does not delete historical assignments,
S3 data, ClickHouse rows, or the frozen final Thompson snapshot.

Do not archive merely to stop assignment; use **Pause** for a temporary stop and **Complete** for a
finished study.

## 11. Analyze the data

Choose the dataset that matches the research question:

- Use `raw_events` for the complete evaluated-activity stream, including outcomes without causal
  attribution.
- Use `experiment_attributions` for evidence tied to assignments, exposures, selected-branch
  outcomes, rewards, and media interactions.
- Join a raw event to its attribution with
  `raw_events.event_hash = experiment_attributions.raw_event_hash`.
- Use the transactional assignment store for an authoritative allocation population.
- Use S3 xAPI when the bounded source attribution contains fields not projected into ClickHouse,
  such as `outcome_key`, or when source-level audit is required.

Review [Experiment Data and Key Reference](data-reference.md) before building an extract, especially
the distinction among score, normalized score, reward, and missing reward.

### Analysis checklist

- [ ] Scope every query by section, project, experiment, and time.
- [ ] Use `enrollment_id` as the pseudonymous participant identity.
- [ ] Choose one canonical xAPI statement type when rollups could duplicate logical evidence.
- [ ] Keep `NULL`, `0.0`, and `1.0` distinct.
- [ ] State how repeated attempts are reduced or retained.
- [ ] Separate section-wide outcomes from selected-branch causal attribution.
- [ ] Report assignment scope and policy version.
- [ ] For Thompson Sampling, account for adaptive allocation in the statistical method.
- [ ] Document project publication, section publication, pause, configuration-change, and cutoff
      times.
- [ ] Apply the approved privacy and retention rules to S3 and exported data.

Start with the [ClickHouse Query Cookbook](queries.md), then adapt only the fields and joins needed
for the approved analysis.

## Lifecycle reference

| Current state | Available transition   | Meaning                                                                             |
| ------------- | ---------------------- | ----------------------------------------------------------------------------------- |
| `draft`       | Start → `active`       | Validate configuration and begin assignment.                                        |
| `draft`       | Archive → `archived`   | Retire an experiment that will not run.                                             |
| `active`      | Pause → `paused`       | Temporarily stop active assignment.                                                 |
| `active`      | Complete → `completed` | End the experiment and freeze its final state.                                      |
| `paused`      | Resume → `active`      | Return to active assignment after manually repeating the relevant preflight checks. |
| `paused`      | Complete → `completed` | End without resuming.                                                               |
| `completed`   | Archive → `archived`   | Hide from active management while retaining history.                                |
| `archived`    | None                   | Read-only historical state.                                                         |

The table shows the standard authoring-UI workflow. The domain lifecycle additionally permits
authorized direct archival from `active` or `paused`; see [Archive the experiment](#10-archive-the-experiment).
