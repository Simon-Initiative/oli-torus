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

## Canonical References

- deployment process: `guides/process/deployment.md`
- feature rollout and scoped flags: `docs/design-docs/scoped_feature_flags.md`
- runtime configuration: `config/runtime.exs`
