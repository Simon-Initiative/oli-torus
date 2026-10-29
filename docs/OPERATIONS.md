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

## GenAI health, capacity and rollout

Configuration/transport semantics: `docs/design-docs/genai.md`. The initial migration
`20261027183342_add_genai_providers_and_tier_capacity` creates exactly
one **OpenAI production** Provider, copies the lowest-ID keyed model's encrypted
credentials and endpoint, and links every existing model. It removes model-level
credentials, adapter and endpoint columns; old routing-policy columns remain. Missing initial keys and heterogeneous adapters/endpoints
require an explicit administrative audit, not guessed credentials or automatic
Provider splitting. Existing same-Provider backups require reassignment.

### Node settings and diagnosis

| Environment | Default | Meaning |
| --- | --- | --- |
| `GENAI_ROUTING_PRIMARY_ONLY` | false | Emergency primary-only routing; bypasses health, tier selection and backup retries |
| `GENAI_HEALTH_CHECKS_ENABLED` | true | Probes/observed gating only; capacity and administrative enablement remain |
| `GENAI_PROBE_INTERVAL_MS` | 180000 | Regular and unavailable recovery interval |
| `GENAI_PROBE_FAILURE_INTERVAL_MS` | 30000 | Suspected failure interval |
| `GENAI_PROBE_DEADLINE_MS` | 10000 | Total synthetic inference deadline |
| `GENAI_PROBE_FAILURE_THRESHOLD` | 3 | Consecutive probe failures to mark unavailable |
| `GENAI_PROBE_RECOVERY_THRESHOLD` | 2 | Consecutive probe successes to recover |
| `GENAI_MAX_CONCURRENT_PROBES` | 4 | Maximum probe tasks per node |

All positive integers are startup configuration; invalid values fail startup rather
than silently disabling safety. Provider policy fields override individual defaults.
Restart to change environment settings. Unknown startup health is eligible only for
structurally valid configuration; stale previously available health is ineligible
after two regular intervals plus deadline. Administrative disablement is distinct
from disabling checks. Request failures never accelerate or mutate probes.

Use authorized GenAI administration to inspect each node's state. For release-console
diagnostics, `Oli.GenAI.Runtime.snapshot()` is credential-free and
`Oli.GenAI.PoolManager.snapshot()` reports current and retiring real pools. Do not dump
`Runtime.routing_configuration/2`, `administrative_configuration/2`, schemas,
changesets, or connection structures into logs; these internal inputs contain secrets.
`Oli.GenAI.Operations.audit()` returns a secret-free persistent audit. `mix oli.genai.audit`
starts the application normally; background probes may run. Use
`GENAI_HEALTH_CHECKS_ENABLED=false mix oli.genai.audit` for probe-free maintenance.

Capacity is per node. Review the sum of configured tier capacities multiplied by
application node count, plus separate probes (one per Provider) and administrative
capacity (four per Provider/resolved origin). Retiring generations temporarily add
connections after resize/endpoint changes. These are connection limits, not global
upstream request/token quotas. Do not use in-place Hackney shrink: fresh generations
become current immediately while old bounded work finishes.

### Staged cutover with deployment controls

1. Preserve an immutable pre-redesign release and a recoverable database backup.
   Stop old nodes before applying the migration; mixed-version operation is unsupported.
2. Apply the migration before any new node starts. It copies credentials to Provider
   and removes API key columns from registered models. Never roll down the schema
   while a new node or administrative maintenance process is running.
3. Start the new release as a canary **excluded from production ingress**. It can run
   independent probes and reconcile actual pools while receiving no ordinary production
   inference. This deployment state supplies observe-first behavior without a new
   scoped routing flag. `Runtime.snapshot().observe_only` remains false because the
   code is capable of routing; ingress exclusion is the control. Restrict direct canary
   access to operators and use explicit administrative test calls.
4. Run the persistent audit and resolve every missing Provider/key, incompatible adapter,
   invalid primary/secondary/backup relationship. Confirm
   Provider ownership, endpoints, node allocations and upstream quotas.
   Claude inference is unsupported; it cannot fall back to the removed legacy adapter.
5. Observe selected probe models, thresholds, failure/recovery, next checks and last
   success on every canary. Test credentials with tiny real inference and a bounded
   streaming request. Verify primary-full selects secondary, both-full busy, backup
   only for outage/eligible pre-output failure, and transport cleanup after cancellation.
   Native checkout timeouts must be local busy, with no health change or second selection.
6. In a production-like test environment, saturate production while probes continue,
   induce main outage and recovery during a backup stream, rotate configuration and
   lower capacity while streams remain active, and confirm retiring work clears.
   The automated local TCP/Hackney suite covers these transitions; it does not replace
   environment-specific connectivity/quota checks or authorize a production outage.
7. Route a limited share of ordinary traffic to verified new canaries, observing per-node
   health, busy/timeouts, request interruption, backup use and retiring pools. Increase
   traffic only while these gates remain satisfactory. Old breaker/counter processes disappear
   with old-node termination; the new release does not supervise them. The primary-only
   emergency override is available as described below. Never use health-check disablement
   to bypass capacity during rollout.

### Emergency primary-only routing

Set `GENAI_ROUTING_PRIMARY_ONLY=true` and restart every serving node. Setting it to
`false` and restarting restores normal dynamic routing. Accepted boolean values are
`true/false`, `1/0`, `on/off`, and `yes/no` (case insensitive).

Primary-only requests read the current primary model and Provider directly from the
database. They ignore secondary/backup configuration, observed health and the routing
cache, and never retry against backup. An independent pool manager reuses the normal
Hackney transport, bounded by each ServiceConfig's `primary_pool_capacity`; it does
not depend on normal tier reconciliation. Provider disablement, credentials,
inference deadlines and stream cancellation still apply. The database and primary
Provider must remain available. Existing requests keep their selected transport;
backup selection is blocked as soon as the override is active.

Startup logs warn when enabled, router decisions report `kill_switch_primary_only`,
and `Oli.GenAI.Diagnostics.snapshot().primary_only` reports the effective node mode.
For an immediate console override without restarting, use
`Application.put_env(:oli, :genai_routing_primary_only, true)` on **each** serving node;
also update deployment environment settings so the override survives restarts.
Health probes continue independently; use `GENAI_HEALTH_CHECKS_ENABLED=false` as well
if probes need to stop. Explicit per-model administrative tests retain their own pools.

### Rollback

Older releases that read credentials from registered models are unsupported. To return
to such a release, stop the new processes and restore the pre-migration database backup
together with the matching release. The migration's `down/0` restores the model key
and connection columns empty; it does not copy Provider settings back into models.
