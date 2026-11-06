# Operations

## Observability

Torus relies on standard Phoenix and Elixir operational signals plus application-specific telemetry.

- logging is part of the normal operational workflow, with logger truncation and structured runtime output used to keep logs useful and bounded
- telemetry events are emitted across core runtime paths and are used to support operational visibility
- Phoenix LiveDashboard is available in development-oriented environments for runtime inspection
- AppSignal is the main APM and error-monitoring integration used for production-oriented observability

## Performance

Performance-sensitive work should be observable through telemetry and APM rather than guessed at after the fact.

- use telemetry and AppSignal to inspect latency, error, and background-processing behavior
- prefer existing caches, aggregated data paths, and scoped feature rollout strategies when introducing operationally risky changes

## Rollout

Rollout is primarily controlled through normal deployment flow plus selective feature enablement where appropriate.

- scoped feature flags are available for staged rollout and controlled exposure
- GitHub Actions drives CI and deployment packaging
- merged `master` changes flow to the test environment through the normal deployment pipeline
- tagged releases drive production deployment

## LKT-AOA Proficiency

LKT-AOA incorporates each evaluated response into the attempt count and decayed
success/failure state before calculating the prediction added to its running
average. The current response therefore affects proficiency immediately.
Direct objectives require three attempts on that objective; page/container/course
scopes require three attempts in total. Parent objectives require at least one
sub-objective with three attempts. Once eligible, the parent's score includes all
available sub-objective states, weighted by their attempt counts.

| Environment variable | Default | Constraint |
| --- | --- | --- |
| `LKT_AOA_LOW_MEDIUM_CUTOFF` | `40` | Finite percentage from 0 through 100 |
| `LKT_AOA_MEDIUM_HIGH_CUTOFF` | `70` | Finite percentage from 0 through 100, greater than the lower cutoff |

These settings are loaded by `config/runtime.exs` at startup; restart the
application after changing them. Invalid settings prevent startup. Internal
probabilities use the corresponding 0–1 values. Low is below the lower cutoff,
Medium includes both cutoffs, and High is above the upper cutoff. Fresh learner,
parent, page, container, course, and class-distribution reads use these settings.
The legacy model and confidence buckets retain their existing 0.4/0.8 boundaries.

No historical recalculation is needed: this transition change precedes the first
release of LKT-AOA.

## Proficiency Confidence

LKT-AOA confidence uses the Hill curve `n^s / (n^s + m^s)`, where `n` is the
number of unique activity parts attempted for the learner/objective, `m` is the
midpoint (confidence 0.5), and `s` controls steepness. Repeated attempts on the
same part do not increase `n`.

| Environment variable | Default | Constraint |
| --- | --- | --- |
| `PROFICIENCY_CONFIDENCE_MIDPOINT` | `5.0` | Finite and greater than zero |
| `PROFICIENCY_CONFIDENCE_STEEPNESS` | `3.0` | Finite and greater than zero |

These settings are loaded at startup; restart the application after changing them.
They replace the exponential curve's `LKT_AOA_CONFIDENCE_SATURATION` setting,
which is no longer used. The Low/Medium/High thresholds remain 0.4 and 0.8;
the defaults first reach Medium at 5 unique parts and High at 8.

Confidence is calculated on read from the persisted unique-part count, before
parent or class aggregation. No confidence value is stored in `learning_states`.
After a restart, fresh reads use the new settings for existing learners without
a backfill or another attempt; already-loaded dashboard views need refreshing.

Deploy the confidence-column removal with the corresponding application version;
older versions still reference that column. Stop older instances before applying
the migration. For rollback, restore the column before starting the older version;
the down migration reconstructs confidence using the active Hill parameters.

## Canonical References

- Deployment process: `guides/process/deployment.md`
- Development and integration branch process: `guides/process/development.md`
- Development and QA PR approvals: `guides/process/pull-request-approvals.md`
- feature rollout and scoped flags: `docs/design-docs/scoped_feature_flags.md`
- experiment reward-handoff monitoring: `docs/runbooks/appsignal/experiment-reward-handoff.md`
- runtime configuration: `config/runtime.exs`
