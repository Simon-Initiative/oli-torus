# Phase 3 routing and execution contract

Phase 3 connects OpenAI production requests to the Phase 2 runtime. A deployment
of this version enables the new execution path; there is no primary-only override
or silent fallback to legacy OpenAI pools when reconciliation fails. Phase 2's
observe-only state describes the preceding version. `Runtime.snapshot/0` now reports
`observe_only: false`. Phase 4 must complete the migration audit and controlled
rollout/rollback procedure before deployment. No deployment is performed here.

## Capacity and configuration

Routing obtains reconciled ServiceConfig and Provider inputs from protected per-config
ETS snapshots, with no per-request database query or wait behind configuration reloads.
A persistent-term discovery handle contains only the ETS identifier, is published once
per runtime, and is removed by an owner monitor even on runtime kill. Only main and backup Provider snapshots are read.
An unknown, structurally valid Provider is initially eligible while its independent
probe runs. Stale or invalid probe configuration is locally ineligible; it does not
fabricate an observed outage. Administrative disablement and observed unavailability
allow an eligible distinct backup. Disabling monitoring preserves administrative
state and all capacity checks.

For eligible main, observe primary's actual checked-out occupancy, then secondary
when primary appears full, otherwise return busy. Backup is never overflow. A plan
carries the model, Provider, ServiceConfig ID, tier, logical transport coordinator,
and a signature of Provider version, model and resolved endpoint. Both completion
dispatch paths pass it to the managed OpenAI adapter. The coordinator chooses its
current physical generation under the startup fence; stale execution inputs are
rejected locally. Capacity-only replacements can use the new generation immediately.
Changes to credentials, model or endpoint invalidate stale selections. Old started
requests retain their old connections and finish; retiring generations stay visible.
Temporary combined occupancy above the new capacity is intentional.

The pool remains the only capacity authority. Selection never reserves a connection.
A race can queue for **1,000 ms**, then returns `busy`; it never selects secondary
again or triggers backup. Connection establishment uses the model timeout (default
8,000 ms); response inactivity uses model receive timeout (default 60,000 ms).
The entire inference, including routing, both attempts, checkout and response, has
an initial **300,000 ms** deadline, overridable through execution options. These
budgets are distinct. No SDK automatic retries run on the managed OpenAI path.

## Backup and streaming

Only connection establishment/closure failures, response inactivity before output,
and HTTP **500, 502, 503 or 504** permit one backup attempt. Generic 429, invalid
input, malformed protocol, cancellation, local pool failures, stale configuration,
and application exceptions do not. Backup must be distinct, eligible and apparently
have capacity. An already-selected backup is never retried. Failure to select backup
preserves the original request error. All attempts share the original total deadline.
Neither errors nor success nor request duration change observed Provider health.

OpenAI execution checks out a real single-use Hackney HTTP/1.1 connection, sends
Provider-owned credentials, and consumes the response while retaining ownership.
Streaming parses incremental SSE events, requires a terminal completion, handles
content and finish in the same event, and rejects malformed events, SSE errors and
truncation. Any failure after content or a tool fragment is exposed becomes
`interrupted_stream`. Error callbacks are withheld until retry has been decided. A final returned error
travels through the dialogue server's tagged error path, discarding a partial
assistant draft and incomplete tool state without duplicating the client error.
Buffer and synchronous response limits prevent unbounded malformed responses.

A monitored worker owns each request's connection, with an owner-death guardian
installed before I/O. The caller invokes callbacks, acknowledging each delivery so
streaming has backpressure. Exceptions in callbacks cancel the worker and propagate;
provider exceptions become safe application errors. An independent total-deadline guardian kills the worker even if a caller callback
blocks. The callback itself belongs to the caller; returning to that caller still
requires its callback to return or the caller to cancel.
Caller cancellation or `:kill` also kills the worker, and Hackney's verified owner
monitoring eventually reclaims active connections and pending checkout requests.
Normal completion/error explicitly closes the request in `after`. This lifecycle
supervision is not an admission registry or a second capacity counter.

## Compatibility and telemetry

Claude's adapter implementation remains unchanged and explicitly unverified. Its
primary dispatch retains the caller model's legacy credentials (the cached projection
intentionally omits these) and stays on Anthropix/Req/Finch without claims of tier isolation,
occupancy selection or Provider-health failover. It is not selected as a managed
backup. Local null providers remain useful for tests/development without a transport.
The deferred Claude limitation requires a future transport decision and verification.

Legacy model fields, shared pools, breaker modules and their read-only admin display
remain for Phase 4 administration/rollback compatibility. Production OpenAI routing
and execution no longer call admission or breaker APIs. Direct administrative model
calls retain their existing dispatch until Phase 4 adds explicit admin context.

Telemetry reports routing selections/rejections; per-tier checked-out occupancy,
capacity and queue depth; checkout duration/outcome and pool identity; pool lifecycle
and cleanup failures; per-attempt outcomes; first output, interruption, total deadline,
cancellation and backup attempts. Request signals remain separate from probe health.
AppSignal aggregates use bounded categories; identifier-bearing telemetry retains
ServiceConfig/tier identity without prompts, keys, URLs or raw error bodies.

The installed Hackney API combines queue checkout and TCP/TLS connection setup in
one public `connect` operation. It exposes no per-request successful checkout-wait
hook; its host-level connect-time metric cannot reliably be subtracted per request.
Report `startup_duration_ms` / AppSignal `pool.startup_ms` with explicit
`checkout_and_connect` timing scope, rather than label it as pure queue wait.
For native `checkout_timeout`, `checkout_timeout_wait_ms` is the measured elapsed
upper bound through timeout (no TCP/TLS connection was started). Telemetry cause
separately identifies `checkout_timeout`, `owner_cancelled`, `startup_deadline`,
`worker_exit` and transport errors. Queue depth remains the native pool statistic.
Pure successful per-request queue duration remains an instrumentation limitation
of the installed API; no application capacity counters or dependency tracing are
introduced to approximate it.

## Evidence

`test/oli/gen_ai/router_test.exs` exercises actual TCP/Hackney production execution,
capacity races, retry boundaries, streaming and cancellation. Existing pool-manager,
transport semantics, probe and monitor tests cover installed-version bounds,
replacement/adoption and separate probe capacity. `test/oli/gen_ai/execution_test.exs`
covers public metadata/options and application errors. Dialogue and administrative
regression suites continue to run. Full Phase 3 checks/reviews are recorded in
`docs/exec-plans/current/features/genai-redesign/execution/phase-3.md`.
