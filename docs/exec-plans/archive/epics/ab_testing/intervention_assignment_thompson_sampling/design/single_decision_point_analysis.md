# Single Decision Point Analysis

## Decision

Torus should support one experiment-controlled Alternatives Group per experiment and remove the `Experiment -> N DecisionPoint` policy hierarchy.

An experiment may still have many delivered placements. Those placements remain distinct interventions with independent sticky assignments, and Thompson Sampling may bind each intervention to its own assessment. This preserves the repeated-intervention workflow without treating several independently optimized policy scopes as one experiment.

## External Research

### UpGrade

UpGrade supports multiple decision points, expressed as `site` and `target` locations where an application asks for and marks an experimental condition. Its documentation also states that a user receives the same experiment condition after assignment and suggests caching the condition set when a context contains multiple decision points. In other words, UpGrade's multiple points are multiple exposure locations for one stable experiment assignment, not independently randomized sub-experiments.

- [Your Application and UpGrade](https://upgrade-platform.gitbook.io/upgrade-documentation/developer-guide/walkthroughs/your-application-and-upgrade)
- [Online Math Game example](https://upgrade-platform.gitbook.io/upgrade-documentation/developer-guide/walkthroughs/example-2-an-online-math-game)
- [UpGrade overview](https://www.upgradeplatform.org/about-upgrade/)

The closest Torus equivalent to an UpGrade decision point is an `experiment_intervention`: a specific page and content element where a condition is applied and exposure is recorded. Torus already permits many interventions under one policy scope.

### Other Experimentation Platforms

LaunchDarkly builds an experiment around one flag or configuration and one randomization unit. A context is assigned to a variation, and flag evaluation records its exposure. Its documentation emphasizes consistent variation assignment for the randomized context rather than independently assigning the same context at several locations.

- [Creating experiments](https://launchdarkly.com/docs/home/experimentation/create)
- [Randomization units](https://launchdarkly.com/docs/home/experimentation/randomization)
- [Experiment events and exposure](https://launchdarkly.com/docs/home/experimentation/events)

Firebase similarly assigns a user persistently to one experiment variant. One experiment may carry multiple Remote Config parameters, which is how coordinated changes across several product locations are delivered without creating independent assignment scopes.

- [Firebase A/B Testing concepts](https://firebase.google.com/docs/ab-testing/ab-concepts)

These platforms preserve a useful distinction:

- one experiment owns one assignment and treatment identity;
- the treatment may affect multiple parameters or exposure locations;
- separate independent assignments are separate experiments unless a factorial or other explicitly modeled design is intended.

## Evaluation of Multiple Torus Decision Points

The current Torus design gives every decision point its own Alternatives Group, mappings, assignment counts, guardrails, policy state, posterior, rewards, and sticky assignments. A learner can therefore receive different condition identities at different decision points in the same experiment.

That model can represent a bundle of independent sub-experiments sharing lifecycle and section participation. It does not provide the principal value found in UpGrade-style multiple decision points: consistent experiment-level treatment across multiple locations.

Potential uses and their fit are:

| Use case | Multiple policy decision points needed? | Better model |
| --- | --- | --- |
| Reuse one Alternatives Group on many pages | No | One experiment with many interventions |
| Collect rewards from several interventions | No | One experiment posterior with per-intervention assessment bindings |
| Apply one coordinated condition across several locations | Not with current semantics | One experiment-level sticky condition with many exposure points; future capability |
| Run unrelated tests under one lifecycle | Technically | Separate experiments |
| Test interactions between several factors | No | Explicit factorial/multivariate design; currently out of scope |
| Optimize several Alternatives Groups independently | Technically | Separate experiments, each with its own hypothesis and evidence |

No current MVP use case justifies independently assigned decision points inside one experiment. Separate experiments make hypothesis, assignment, analysis, lifecycle, and reporting boundaries clearer.

## Current Complexity Cost

The decision-point concept currently appears in 53 implementation, test, migration, and work-item files, including 26 production files and 16 test files. It contributes at least:

- a dedicated `experiment_decision_points` table and schema;
- an `experiment_decision_point_conditions` join table and schema;
- repeated `experiment_id` plus `decision_point_id` foreign keys on conditions, assignments, and policy states;
- per-point validation, graph reconciliation, ordering, mapping, activation, conflict, query grouping, locking, telemetry, and reporting;
- nested authoring request and LiveView state structures;
- analytics and xAPI dimensions whose distinction from experiment and intervention is difficult to explain;
- ambiguity handling for multiple active point matches;
- migration logic that normalizes conditions across points and maintains compatibility invariants.

This is structural complexity rather than incidental code volume. Keeping the table as a one-to-one wrapper would preserve most of it.

## Recommended Domain Model

### Experiment Definition

Move the single policy scope onto `experiment_definitions`:

- `alternatives_resource_id`;
- policy parameters currently on `experiment_decision_points` (`prior_alpha`, `prior_beta`, warm-up and guardrail fields, and `reward_source`);
- existing immutable `algorithm`, assignment unit, lifecycle, project, and section participation.

The current decision-point key can be derived from the Alternatives resource identity. A separate title and position are unnecessary for a singular configuration.

### Conditions and Mappings

Keep conditions experiment-owned. With one Alternatives Group, the mapping is one-to-one, so move `option_id`, `weight`, and `position` onto `experiment_conditions` and remove `experiment_decision_point_conditions`.

The condition table already contains compatible legacy columns for these values, reducing the conceptual and migration distance.

### Interventions

Make `experiment_interventions` belong directly to the experiment. Preserve `(experiment_id, page_resource_id, content_element_id)` uniqueness.

- Weighted random continues to discover these placement identities lazily.
- Thompson Sampling continues to configure them explicitly with assessment bindings.

These rows should be called placements or interventions in product and code. They are the actual exposure points.

### Assignments

Remove `decision_point_id` from assignments. An assignment remains scoped by experiment, intervention, enrollment, condition, section, and user.

The sticky uniqueness rule remains `(intervention_id, enrollment_id)` because the approved repeated-intervention workflow intentionally permits a learner to receive a fresh policy draw at each placement. If Torus later adds coordinated multi-location assignment, that should be an explicit experiment assignment mode rather than an implicit consequence of multiple decision points.

### Policy State and Rewards

Keep one policy-state row per experiment and algorithm; remove `decision_point_id` from its identity and uniqueness constraint. Thompson posterior state remains keyed by experiment condition.

Rewards continue to resolve through assignment -> intervention -> assessment binding and update the experiment's one policy state.

### Evidence and Analytics

New operational and analytical evidence should use:

- experiment identity for hypothesis, policy, and posterior scope;
- intervention identity for exposure location and assessment binding;
- condition identity for treatment;
- Alternatives resource identity for the reusable content group.

`decision_point_id` should be removed from new transactional and event contracts. If already-deployed historical analytics require it, retain it only as a nullable legacy dimension during an explicit compatibility window; do not manufacture a replacement value.

## Implementation Simplifications

The cleanup would permit:

1. Singular create/update request fields instead of nested `decision_points` lists.
2. Direct experiment-to-Alternatives conflict checks.
3. Direct experiment condition reads without mapping joins.
4. One policy-state lookup and lock per experiment.
5. Direct intervention materialization from the matching experiment.
6. Removal of per-point grouping, ordering, ambiguity, policy hydration, and reporting loops.
7. A single experiment configuration card in LiveView rather than repeatable decision-point cards.
8. Simpler activation errors and lifecycle reconciliation.
9. Clearer telemetry and analytics terminology.

## Migration Strategy

This work is still under active feature development and is deployed only in QA. Use generated PostgreSQL migrations with explicit `up/0` and `down/0`, plus ordinary ClickHouse migrations where evidence dimensions change, to replace the pre-release schema directly:

1. Remove or recreate disposable QA experiment operational and analytical rows as required by foreign-key ordering.
2. Move group, mapping, policy, intervention, assignment, reward, and policy-state ownership directly to the experiment in the final schema.
3. Replace decision-point indexes and constraints with experiment-scoped equivalents.
4. Drop decision-point columns, mappings, and tables without implementing row transformation, backfill, or dual reads/writes.
5. Verify the exact forward schema and dependency-safe rollback schema. Rollback restores schema shape, not discarded QA experiment data.

Existing Alternatives content, revisions, and publications remain outside this destructive experiment-data boundary and continue to use read-time strategy normalization without content migration or republication.

## Scope Boundary

This recommendation does not change the approved repeated-intervention behavior:

- a single experiment may appear at many placements;
- each placement remains a distinct sticky assignment opportunity;
- all accepted Thompson rewards update the same experiment posterior;
- weighted random still requires no assessment bindings;
- Thompson Sampling still requires explicit intervention/assessment bindings.

It also does not introduce UpGrade-style experiment-level condition consistency across placements. That is a plausible future assignment mode, but it should be designed explicitly with its own statistical and completion semantics.

## Recommendation

Remove multi-decision-point support now. It has no demonstrated MVP use beyond grouping independent experiments, while repeated placements already cover the useful multi-location workflow. Model one experiment as one hypothesis, one Alternatives Group, one policy and posterior scope, N conditions, and N placement interventions.

Before implementation, update the PRD, requirements, FDD, and plan to replace `N decision points` with `one experiment policy scope and N interventions`, then implement the schema collapse as a dedicated migration phase.

## Decision Log

### 2026-08-13 - Drop QA experiment-data migration requirements

- Change: Replaced the preservation/backfill migration strategy with direct reversible schema replacement.
- Reason: The feature is deployed only in QA and existing experiment operational and analytical data is disposable.
- Evidence: Explicit product and deployment-scope clarification.
- Impact: Implementation retains PostgreSQL and ClickHouse migrations but omits data mapping, dual compatibility, and historical experiment-row preservation.
