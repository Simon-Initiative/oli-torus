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

Stored confidence is recalculated when a learner/objective state next processes
an evaluated attempt. Changing these settings does not backfill existing states.

## Canonical References

- deployment process: `guides/process/deployment.md`
- feature rollout and scoped flags: `docs/design-docs/scoped_feature_flags.md`
- experiment reward-handoff monitoring: `docs/runbooks/appsignal/experiment-reward-handoff.md`
- runtime configuration: `config/runtime.exs`
