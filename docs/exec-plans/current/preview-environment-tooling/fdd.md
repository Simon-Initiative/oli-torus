# Preview Environment Seeding and User Masquerade - Functional Design Document

## 1. Executive Summary

This design adds a deny-by-default `Oli.DevQATools` subsystem for two related non-production capabilities: policy-controlled execution of deployed-safe `Oli.Scenarios` definitions and temporary system-administrator masquerade as an existing user. `Oli.DevQATools` is the only deployed seeding entry point. It owns configuration checks, catalog resolution, validation policy, run policy, durable run history, job enqueueing, summaries, audit events, and telemetry; `Oli.Scenarios` remains responsible for parsing and executing directives through existing Torus domain contexts.

Seed execution is asynchronous through a dedicated Oban queue with concurrency `1`. A database-backed run claim and Oban uniqueness prevent duplicate execution across nodes, restarts, and rolling deployments. Startup coordination, the administrator workbench, and the read-only automation endpoint all call the same service. Custom YAML exists only in the active LiveView and the queued job payload long enough to execute; durable run history stores its digest and redacted results, never the body.

Masquerade is implemented at the authentication/session boundary. Signed session state preserves the original system administrator separately from the effective target user. Existing authorization receives only the target identity, while a narrowly scoped actor identity is available to auditing and the stop operation. A shared root-layout component renders the persistent accessible warning across server-rendered, LiveView, and React-mounted pages.

The design satisfies FR-001 through FR-012 without introducing a general scenario HTTP execution API, a second feature-flag system, custom-definition storage, rollback semantics, or an action-specific masquerade deny list.

## 2. Requirements & Assumptions

- Functional requirements:
  - FR-001 and FR-002: gate every capability with `DEV_QA_TOOLS_ENABLED == "true"`; optionally enqueue one approved `DEV_QA_SEED_PROFILE` after startup without affecting readiness.
  - FR-003 and FR-004: provide one deployed seeding service and an explicit deployed-safe scenario contract that rejects unsafe directives, hooks, assertions, and file references before mutation.
  - FR-005: add deterministic `bulk_users` and `simulate_progress` directives, migrate Stagehand behavior and repository call sites, and remove or deprecate the standalone bypass.
  - FR-006 and FR-007: provide a system-administrator workbench with predefined catalog selection, transient YAML editing, validation, confirmation, execution, and complete run monitoring without custom-definition persistence or file transfer.
  - FR-008 and FR-009: expose a purpose-authenticated status-only interface and execute durable, observable, concurrency-safe jobs with explicit repeat policy.
  - FR-010 through FR-012: support expiring, non-chainable masquerade with target-only permissions, dual-identity audit attribution, and a persistent accessible warning and stop control.
- Non-functional requirements:
  - Security boundaries are enforced independently in runtime configuration, router/on-mount hooks, service functions, worker execution, session restoration, and automation authentication.
  - Seed work never runs in request or LiveView processes. The dedicated queue is serialized and internal learner simulation uses bounded batches and supervised tasks.
  - Failures are durable and redacted. Seed mutations committed before a later failure or assertion failure are not rolled back.
  - Telemetry and summaries are bounded and exclude YAML bodies, learner responses, credentials, session tokens, and personal data.
  - Implementation must pass security, performance, Elixir, UI, and requirements review gates under repository policy.
- Assumptions:
  - Seed data is synthetic and deployments enabling this capability have separately disabled or redirected email, payments, LTI grade passback, and other external side effects.
  - A platform system administrator is represented by the repository's existing administrator authorization checks; institution and section administrators are not sufficient.
  - Startup has access to configured, existing seed-owner author and institution identities. The service fails validation/configuration rather than creating default ownership records.
  - Predefined profiles are immutable codebase assets under a dedicated approved root and declare metadata including identifier, description, version, execution policy, and runtime-safe certification.
  - No seed-specific request-size cap, job timeout, directive-count limit, user-count limit, or pending-job cap is introduced initially; existing endpoint body protection, queue serialization, batching, and telemetry provide the first operational boundary.
  - Masquerade targets the delivery `User` identity. Existing linked author behavior is not used to inherit the original administrator's author privileges.

## 3. Repository Context Summary

- What we know:
  - `lib/oli/scenarios.ex` is the public scenario API; parsing, validation, execution state, summaries, handlers, hooks, and `use` composition live under `lib/oli/scenarios/`.
  - Scenario execution is synchronous today and its runtime options can create default ownership context, so deployed execution needs a stricter adapter and explicit context.
  - `lib/oli/utils/stagehand.ex` and `lib/oli/utils/stagehand/` contain bulk enrollment and learner simulation source behavior. The current implementation uses unbounded `Task.async` within chunks and supports multiple choice, short answer, and multi-input responses.
  - `Oli.Application` supervises Oban and runtime services. Oban configuration in `config/config.exs` already uses named queues and test mode disables queues.
  - System-admin pipelines and LiveView sessions exist in `lib/oli_web/router.ex`; the existing user detail route is `/admin/users/:user_id`.
  - `OliWeb.Common.Monaco` and the `MonacoEditor` hook already bridge editable text between LiveView and Monaco and can be configured for YAML.
  - Phoenix root layouts wrap server-rendered and mounted React surfaces, making them the correct common rendering point for the masquerade warning.
  - PostgreSQL is the transactional source of truth; AppSignal consumes application telemetry; `Oli.Auditing` is the existing audit boundary.
- Unknowns to confirm during slice design:
  - The exact existing automation credential mechanism to reuse for the status endpoint; the endpoint must not invent a weaker shared-secret convention.
  - The canonical configured seed-owner author and institution lookup keys in each deployment manifest.
  - Which existing assertions can be certified non-mutating for the first deployed-safe allowlist.
  - Which current scenario directives are required by `review_demo` and `playwright_smoke`; only that minimal set should be certified.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

`Oli.DevQATools.Config` parses runtime values once into application configuration. `enabled?/0` is true only for the exact string `"true"`; the selected profile never enables the feature. Production deployment policy validation rejects an enabled production manifest, while every application boundary still enforces the flag.

`Oli.DevQATools.Seeding` is the narrow public service. Its functions return tagged results and accept an explicit caller context:

- `catalog/1` returns certified predefined metadata, not arbitrary files.
- `validate/3` resolves source text, parses it, applies schema and deployed-policy validation, resolves explicit ownership, computes a SHA-256 digest, and returns a bounded validation result.
- `request_run/3` repeats authoritative validation, creates or finds the policy claim and durable run, enqueues `SeedWorker`, and audits the request in one transaction.
- `get_run/2` and `list_runs/2` return redacted projections appropriate to the caller.
- `startup_request/0` resolves only the configured predefined identifier and uses the same validation and request path with a trusted startup actor marker.

`Oli.DevQATools.Seeding.Catalog` loads only manifests beneath a fixed application-owned profile root such as `priv/dev_qa_tools/scenarios/`. Each catalog entry explicitly lists its root YAML file, reusable include root, policy, and certification version. Catalog loading canonicalizes paths and rejects absolute paths, traversal, symlinks escaping the approved root, remote references, and unlisted files. Test scenarios are never discovered automatically.

`Oli.DevQATools.Seeding.Policy` walks the fully parsed definition before execution. It allowlists directive types, safe function variants, and non-mutating assertions; rejects hooks; and permits `use` only for predefined definitions and only inside that entry's include root. Custom YAML cannot use file composition. Validation completes before the first handler mutates data. The validated representation and policy version are passed to execution so the worker cannot bypass or reinterpret a weaker policy.

`Oli.DevQATools.Seeding.SeedWorker` loads the durable run by ID, rechecks the capability, atomically claims it, records attempt/start state, executes through `Oli.Scenarios`, stores a bounded summary, and transitions the run to a terminal state. Oban retries only unexpected transient failures; deterministic validation/execution errors are recorded terminally and return `:ok` to avoid futile retries. The worker has bounded attempts and no execution timeout.

`Oli.DevQATools.Seeding.StartupCoordinator` starts after Repo and Oban. It sends itself a non-blocking continuation, confirms Repo/migration readiness, and calls `startup_request/0`. No profile means no action. An unknown profile creates a durable configuration-error run/audit signal without enqueueing scenario work. Failure never terminates application supervision or readiness.

`bulk_users` and `simulate_progress` become normal `Oli.Scenarios` directive types, validators, and handlers. Scenario-owned services under `lib/oli/scenarios/` encapsulate deterministic name/identity generation and progress simulation. `bulk_users` records the group and stable indexed user references in execution state. `simulate_progress` resolves only the named section/users, selects pages and answers from an explicitly seeded PRNG state, and processes users in configurable internal batches with a conservative fixed default and `Task.Supervisor.async_stream_nolink/5`. Unsupported content returns warnings; unexpected per-user failures become structured directive errors.

`OliWeb.Admin.SeedWorkbenchLive` is a thin, system-admin-only adapter. It uses the shared Monaco component in YAML mode, keeps editor text in socket state, and discards it after enqueue/navigation. Validation and execution always call the server service; a forged client event gains no authority. The run table reads durable records and can subscribe to PubSub notifications for status refresh, with periodic refresh as a fallback.

`OliWeb.Api.DevQASeedStatusController` provides only the configured startup profile's matching run status. It is behind capability and purpose-authentication plugs. It accepts a profile ID and digest (or an opaque run reference bound to both), returns a fixed projection, and maps unknown/unauthorized/mismatched requests to the same response status and body shape. No route accepts execution requests.

`Oli.DevQATools.Masquerade` owns start, stop, restore, expiry, and invalidation. Start requires an enabled capability, current non-masqueraded system administrator, and valid active target. It writes signed session state containing actor user/author identifier, target user identifier, issued-at time, expiry, and a random reference. On every request, an auth plug restores the actor separately, validates the flag/expiry/target, then assigns the target as `current_user`. Invalid state is cleared and audited. Existing authorization therefore sees only the target. Stop is the sole actor-authorized exception, clears state, restores normal actor identity, and redirects to a fixed safe admin user-detail/dashboard destination rather than trusting an arbitrary return URL.

`OliWeb.Components.MasqueradeBanner` is rendered by every authenticated root layout. It uses text plus high-contrast magenta styling, names the target, and submits an immediately available labeled stop action. Root-layout assignment is derived from validated server session state, not client props, so LiveView and mounted React pages inherit the same treatment.

### 4.2 State & Data Flow

Seed request flow:

1. Startup coordinator or admin LiveView calls `Seeding.validate/3` with predefined identity or transient YAML plus explicit owner context.
2. The service checks the runtime flag and caller, resolves/catalogs input, parses YAML, expands permitted predefined includes, applies schema and deployed-policy validation, and computes the normalized content digest.
3. On confirmed execution, a transaction inserts a run/claim and Oban job, records its ID on the run, and writes the audit event. A conflicting non-concurrent claim returns the existing run or a structured duplicate rejection.
4. The worker claims the run, executes directives in scenario order, updates bounded progress after directives/batches, and commits a terminal success or failure summary.
5. LiveView and automation callers read redacted projections. PubSub is advisory; PostgreSQL remains authoritative.

Masquerade request flow:

1. A system administrator starts masquerade from the existing user detail page through a POST/event protected by CSRF and server authorization.
2. The service validates the target and stores signed session state; audit records actor and target identifiers plus bounded request context.
3. Each subsequent request restores `masquerade_actor` and assigns the target as the effective `current_user`; ordinary plugs, LiveViews, controllers, and domain authorization receive no actor privilege.
4. The root layout renders the warning. Stop, logout, expiry, feature disablement, or invalid target clears the session and audits the reason.

### 4.3 Lifecycle & Ownership

- Application configuration owns enablement and profile selection for the lifetime of the release; no UI can change either value.
- Codebase-owned profile files are immutable release assets. Their digest and catalog metadata identify a version.
- The LiveView owns custom YAML only during the editing/request lifecycle. The Oban job may carry encrypted-at-rest database job arguments only if required to bridge execution; preferred implementation stores a short-lived encrypted payload referenced by the run and deletes it in an `after` path. In either case, YAML is excluded from `seed_runs`, logs, telemetry, audit metadata, and UI history.
- `seed_runs` owns durable lifecycle state. Legal transitions are `requested -> queued -> running -> succeeded|failed|rejected`; retry updates attempt metadata without returning a terminal run to running.
- Scenario execution state owns stable references and aggregate warnings/errors during execution. Only an allowlisted bounded projection is persisted.
- Session storage owns masquerade state. There is no database-backed active-session registry in the initial design; per-request target/config validation guarantees bounded invalidation.

### 4.4 Alternatives Considered

- Expose `Oli.Scenarios` directly from a LiveView: rejected because UI-only authorization cannot protect workers/startup, and existing hooks and filesystem composition are too broad for deployed input.
- Continue Stagehand as a parallel service: rejected because it duplicates scenario orchestration and creates an unvalidated execution bypass. Its reusable logic moves behind scenario-owned handlers.
- Run startup seeding in application initialization: rejected because long work and failures would affect readiness and restart behavior. A coordinator only enqueues durable work.
- Use only Oban uniqueness: insufficient for durable once-per-database semantics after Oban uniqueness periods and pruning. A database claim keyed by execution policy is authoritative; Oban uniqueness reduces duplicate queued work.
- Store custom definitions for reruns: rejected by FR-007 and privacy requirements. Only digest, policy metadata, and redacted outcome persist.
- Replace `current_user` globally with a composite actor/subject object: rejected as a high-risk cross-application refactor. Separate actor assigns plus unchanged effective-user authorization are simpler and easier to verify.
- Add an action deny list during masquerade: rejected for initial scope. Deployment-wide external integration containment is explicit, and target-user permissions remain faithful.

## 5. Interfaces

- Runtime configuration:
  - `DEV_QA_TOOLS_ENABLED`: enabled only when exactly `true`; all other values disable.
  - `DEV_QA_SEED_PROFILE`: optional predefined catalog identifier; ignored for execution while disabled and reported as configuration error when unknown while enabled.
  - Existing configured author/institution identifiers are required by startup execution; their final environment variable names are chosen during detailed slice design and documented with deployment manifests.
- Domain service contracts:
  - `Seeding.validate(source, caller, opts) :: {:ok, ValidationResult.t()} | {:error, reason}`.
  - `Seeding.request_run(validation_or_source, caller, opts) :: {:ok, SeedRun.t()} | {:error, reason}`; this function always performs authoritative validation.
  - `Seeding.startup_request() :: :disabled | :not_configured | {:ok, SeedRun.t()} | {:error, reason}`.
  - `Seeding.list_runs(caller, page_opts)` and `get_run(caller, id)` return redacted view models.
  - `Masquerade.start(conn, actor, target)`, `restore(conn)`, and `stop(conn)` return explicit success/invalid/expired/disabled results and session updates.
- Scenario DSL:
  - `bulk_users`: required `name` and `section`; optional integer `instructors` and `students`, each default `0` and non-negative with at least one non-zero; optional integer `random_seed`.
  - Member references are `<name>_instructor_<index>` and `<name>_student_<index>`. Generated emails use collision-safe local parts at `seed.example.invalid`; callers cannot select provider/domain/identity format.
  - `simulate_progress`: required `section` and `users`; users are a bulk group reference or explicit user-reference list; `percent_complete` and `percent_correct` default to `1.0` and are inclusive floats from `0.0` to `1.0`; optional integer `random_seed`.
  - Both directives return structured created references, warnings, and errors through normal scenario execution results.
- Admin web interface:
  - A capability-gated route under the existing system-admin scope renders the workbench.
  - Events are `load_profile`, `editor_changed`, `validate`, `confirm_run`, `run`, and run refresh. Every sensitive event rechecks feature and system-admin status.
  - `Act as user` appears on the existing admin user detail only when authorized and enabled; stop uses a CSRF-protected route/event available only with valid masquerade actor state.
- Automation interface:
  - Read-only `GET` under the existing automation API namespace, guarded by reused purpose authentication and feature gate.
  - Success projection: `run_id`, `profile_id`, `content_digest`, `status`, timestamps, `attempt_count`, and bounded stable identifiers/slugs on success.
  - It returns no YAML, credentials, actor/target personal data, arbitrary history, raw errors, or mutation affordance.
- Telemetry interface:
  - `[:oli, :dev_qa_tools, :seed, :validation]`, `:request`, `:execution`, and `:rejection` events with duration/outcome/source/profile/digest/policy and bounded aggregate counts.
  - `[:oli, :dev_qa_tools, :masquerade, :lifecycle]` with action/outcome and non-personal identifiers suitable for AppSignal tags.

## 6. Data Model & Storage

- Add `dev_qa_seed_runs` with:
  - UUID or bigint primary key; `profile_id` nullable; `source` enum/string (`startup`, `predefined_admin`, `custom_admin`); `content_digest`; `catalog_version`/policy version; `execution_policy`; owner author/institution foreign keys; requesting actor foreign key nullable for startup; `oban_job_id` nullable; status; attempt count; requested/started/finished timestamps; bounded progress and summary maps; redacted error code/message; standard timestamps.
  - Indexes on status/time for the workbench, `oban_job_id`, and profile/digest lookup for automation.
  - Check constraints for legal source/status/policy values and summary size enforced in application serialization.
- Add `dev_qa_seed_claims` or an equivalent unique claim key with `scope_key`, `profile_or_digest`, and `policy_key`. Unique indexes encode once-per-database and once-per-digest ownership. Repeatable runs receive a unique request nonce and do not conflict, while simultaneous execution is still serialized by the queue.
- Use foreign keys with restrictive or nullifying behavior appropriate to immutable history; deletion of an actor must not delete run history. Store IDs and bounded display snapshots only where audit requirements require historical readability.
- Do not add a custom-definition table or YAML/body column to run history.
- If custom YAML cannot safely fit in Oban args under deployment encryption policy, use a short-lived `dev_qa_seed_payloads` record containing application-encrypted text, referenced by job ID, deleted after terminal execution and pruned after abandoned jobs. It is transport state, never reusable history.
- Existing scenario-created projects, publications, sections, products, users, enrollments, attempts, and analytics records remain in their canonical tables and are created through existing contexts.
- Masquerade adds no domain table. Existing audit storage records lifecycle events; signed session state contains identifiers, timestamps, expiry, and random reference only.

## 7. Consistency & Transactions

- `request_run/3` uses `Ecto.Multi` to acquire/insert the policy claim, insert the run, insert the Oban job through `Oban.insert/2` with the same transaction, attach the job ID, and audit the request. A unique-index conflict is translated to a duplicate/existing-run result.
- The claim key derives from the database identity plus policy: once-per-database ignores digest changes for the profile; once-per-definition-digest includes normalized digest; repeatable includes request identity. Database identity is derived internally, never accepted from YAML or HTTP.
- Oban uniqueness includes queue, worker, and the run's computed uniqueness key across queued/executing/retryable states. It is defense in depth, not the source of once-policy truth.
- Worker status changes use conditional updates or row locks so only one attempt owns `queued -> running`. A terminal run cannot be reclaimed.
- Scenario directives retain their existing transaction boundaries. The entire scenario is deliberately not wrapped in one long transaction; preceding mutations remain committed after later failure. The terminal summary says `partial_mutations_possible: true` for failed executions after mutation begins.
- Progress updates are monotonic and best-effort. Execution correctness does not depend on PubSub delivery.
- Masquerade session changes are atomic with the response. Audit failure handling follows existing security-audit policy; start must fail closed if the required audit record cannot be written.

## 8. Caching Strategy

- No correctness-sensitive cache is introduced. Runtime enablement is read from immutable application configuration, and PostgreSQL is authoritative for runs and claims.
- Parsed predefined profiles may be cached by `{profile_id, content_digest, policy_version}` within a node to reduce repeated parsing. Cache misses and node disagreement are harmless because the digest and database claim remain authoritative.
- Custom YAML, target validity, active masquerade state, and run status are never cached.
- The workbench may retain catalog metadata in socket assigns and refresh run status through PubSub/polling; it must reauthorize and requery before actions.

## 9. Performance & Scalability Posture

- Add Oban queue `dev_qa_seeding: 1`; seed workers do not occupy latency-sensitive queues. Test configuration continues to use manual/disabled queues as established.
- `simulate_progress` uses fixed-size batches and `async_stream_nolink` with modest `max_concurrency`, finite per-task timeout selected from existing attempt behavior, and ordered aggregation. This bounds processes and database checkout pressure while allowing the job itself to run without a seed-specific global timeout.
- Bulk inserts may be used only through domain-safe APIs that preserve enrollment, audit, and identity invariants. Avoid per-row lookup N+1s by preloading section content/activity registrations once per directive and resolving users in batches.
- Run listing is paginated and selects bounded summary fields; progress writes are throttled by batch/directive, not per response.
- Persisted summaries cap lists of warnings, errors, and entity identifiers and include aggregate omitted counts.
- Telemetry records directive/user/page/attempt counts, batch size, effective concurrency, database duration, total duration, and queue latency/pressure. Numeric performance limits are deferred until rollout evidence exists, consistent with the PRD.

## 10. Failure Modes & Resilience

- Disabled or malformed capability flag: all adapters and services return disabled, routes are absent or non-disclosing, workers fail closed, and stale masquerade is cleared on the next request.
- Unknown startup profile: record a configuration-error result and emit warning/audit/telemetry; do not enqueue and do not affect health.
- Missing owner context: validation fails before mutation with a redacted configuration code; never create default author/institution records.
- Unsafe YAML/directive/assertion/hook/path: policy validation rejects the full definition before execution and records no YAML body.
- Duplicate request: the database unique claim selects the existing run or reports a structured conflict; it never starts a second non-concurrent execution.
- Node crash or transient database failure: Oban retries within bounded attempts. The worker uses stable references and run claims; handlers must be made idempotent where retry can re-enter them. Non-idempotent residual risk is surfaced as a failed partial run rather than reported as success.
- Assertion failure: mark the run failed, retain assertion summary, and explicitly report that preceding changes were not rolled back.
- Unsupported page/activity: record bounded structured warning and skip it. Unexpected simulation errors become structured errors and fail the directive/run according to scenario semantics.
- Payload unavailable/decryption failure: fail terminally with a redacted payload error and clean transport storage.
- PubSub loss or LiveView disconnect: the job continues; reconnect reads PostgreSQL status.
- Invalid, disabled, or deleted masquerade target; expired state; actor logout; or flag disablement: clear state, audit the reason, and continue as the restored actor when safe or signed out otherwise.
- Tampered session: signature verification fails, state is discarded, no target identity is installed, and a bounded security event is emitted.
- Audit/telemetry failure: telemetry is non-blocking; required security audit writes for start/request fail closed according to existing auditing conventions.

## 11. Observability

- Emit validation request/result, execution request/start/retry/progress/success/failure, unsafe rejection, duplicate prevention, startup configuration error, and queue-latency telemetry.
- Measurements include duration and aggregate workload; metadata includes source, profile ID when predefined, digest prefix/full non-secret digest as policy permits, execution policy, result code, worker attempt, and queue. Exclude YAML, names/emails, responses, credentials, stack traces, and tokens.
- Log one conspicuous bounded warning at boot when the capability is enabled and one when a startup profile is configured. Never infer safety from environment naming.
- Audit predefined load, validation, execution request/result, and masquerade start/stop/expiry/invalidation. Custom executions are identified only by digest. Masquerade audit includes actor ID, target ID, timestamp, session reference, and bounded request IP/user-agent metadata under existing privacy rules.
- AppSignal dashboards track completion/failure rate, duration, retries, rejection reason, duplicate prevention, queue latency/depth, aggregate workload, and masquerade lifecycle counts. Alerts should focus on stuck queue age, repeated startup failure, and unexpected enablement signals rather than individual synthetic-data errors.
- The workbench shows durable status, attempts, initiator, timestamps, duration, aggregate summary, and redacted error codes. Automation sees the narrower contract in section 5.

## 12. Security & Privacy

- Defense in depth: compile/runtime config, router plug, LiveView on-mount/event checks, service authorization, worker flag check, automation authentication, and per-request masquerade restoration all fail closed independently.
- The profile variable cannot enable the capability. No hostname, Mix environment, ingress state, existing feature flag, or existing data enables it. Deployment CI/policy rejects the flag in production manifests.
- Catalog paths are application-owned and canonicalized; only explicitly registered files and include roots are accessible. Remote URLs, absolute paths, traversal, escaping symlinks, arbitrary `use`, hooks, dynamic modules/functions, and non-certified assertions are rejected before execution.
- YAML is treated as untrusted input. Server parsing uses safe scalar construction, existing request limits, strict directive schemas, bounded error rendering, and no atom creation from user strings.
- Every mutation uses explicit existing author/institution ownership and existing Torus contexts, preserving multi-tenancy and publication rules.
- Automation reuses a purpose-scoped credential mechanism, uses constant/non-enumerable error responses, and can read only the configured startup run. It cannot list history, validate YAML, or trigger work.
- Custom YAML bodies and learner responses do not enter durable run history, audit data, logs, telemetry, or UI history. Predefined profiles contain only synthetic identities under `seed.example.invalid` and no passwords or credentials.
- Masquerade start requires a current system administrator and prohibits chaining. The actor identity is never merged into target authorization. The stop capability is bound to signed actor/session state and cannot be invoked by the target outside that session.
- Session state uses Phoenix signed/encrypted session facilities, rotates or renews the session at start/stop to resist fixation, has a configured finite lifetime, and is invalidated on logout. Stop redirects to an allowlisted route rather than a supplied URL.
- The banner communicates state with text and semantic labeling, not color alone. Focus, keyboard access, and screen-reader naming are tested.
- Permitted target mutations are real. Deployment configuration, not masquerade logic, disables or redirects outbound email, payments, LTI grade passback, and approved external integrations.

## 13. Testing Strategy

- Configuration and service ExUnit tests:
  - Cover exact flag parsing, absent/blank/malformed values, unrelated flags/environments, optional/unknown profiles, explicit owner resolution, and every public service's disabled/unauthorized behavior (AC-001 through AC-009, AC-038).
  - Verify catalog certification, path canonicalization, symlink/traversal/remote rejection, custom `use` rejection, hook/function/assertion allowlists, full pre-mutation validation, safe parser behavior, and redaction (AC-010 through AC-012, AC-048, AC-049).
- Scenario directive tests:
  - Unit-test schemas/defaults/ranges and stable reference generation. Run both directives through real scenario handlers with named and existing sections, deterministic seeds, collision retries, multiple cohorts, supported activities, unsupported warnings, and worker failures (AC-013 through AC-015, AC-036, AC-037, AC-047).
  - Add YAML-driven `Oli.Scenarios` integration coverage for `review_demo` and `playwright_smoke` using real domain operations, verifying the required course/publication/product/section/user/enrollment/progress artifacts and bounded stable summaries without fixtures or mocks (AC-042 through AC-045).
- Persistence and Oban tests:
  - Use `Oban.Testing` to verify transactional insertion, job linkage, retry classification, no global timeout, queue selection, terminal transitions, payload cleanup, and redaction.
  - Exercise concurrent tasks against the unique claim to prove only one once-policy run is admitted. Simulate restarts/rolling-node enqueue attempts and verify once-per-database/digest behavior and serialized queue configuration (AC-004 through AC-007, AC-017, AC-018, AC-024 through AC-026, AC-039, AC-040, AC-046).
- LiveView and controller tests:
  - Verify system-admin-only route visibility and forged event rejection; Monaco YAML initialization, edits, transient predefined copies, syntax/schema/policy errors, confirmation, enqueue state, complete paginated history, and no custom persistence/upload/download (AC-016 through AC-021).
  - Verify purpose authentication, configured-profile/digest matching, fixed response projection, non-enumerable failures, and absence of trigger routes (AC-022, AC-023, AC-041).
- Masquerade tests:
  - Cover start/stop, role rejection, forged requests, chaining, expiry, logout, session renewal, deleted/disabled targets, flag disablement, actor/target separation, admin-as-target behavior, no inherited actor privilege, audit records, persisted target mutations, and safe redirects (AC-003, AC-027 through AC-032, AC-035, AC-050).
  - Component/LiveView tests render the banner in representative server, LiveView, and React-mount root layouts and verify magenta treatment, target text, stop control, keyboard operation, accessible name, and non-color cue (AC-033, AC-034).
- Operational and manual verification:
  - Validate deployment manifests prohibit production enablement and explicitly contain external side effects for enabled QA deployments.
  - On fresh preview and sandbox databases, run both profiles, roll/restart pods, inspect AppSignal/Oban/run history, poll Playwright status, verify stable identifiers, exercise instructor/learner masquerade, and confirm disabled deployments expose nothing.
- Required implementation gates:
  - Targeted `mix test` modules, scenario validation and runners, `mix format`, compile checks, and repository security/performance/Elixir/UI/requirements reviews.

Acceptance-criterion traceability clarifications:

- AC-002 is verified by configuration tests proving Mix environment, hostname, unrelated feature flags, and existing data cannot enable the capability.
- AC-005 is verified by a startup-coordinator test that enables tools without a profile and asserts that no run or job is created.
- AC-006 is verified by concurrent/repeated startup enqueue tests against the once-per-database and once-per-digest claim keys.
- AC-008 is verified by adapter contract tests proving startup and admin requests enter the same `Seeding.validate/3` and `Seeding.request_run/3` policy path; the automation interface remains status-only.
- AC-011 is verified by policy tests for non-allowlisted directives/functions, hooks, URLs, absolute paths, traversal, escaping symlinks, and unapproved includes before any handler executes.
- AC-014 is verified by deterministic bulk-user tests for indexed references, realistic names, collision handling, the `seed.example.invalid` domain, and rejection of caller-selected identity formats/providers/domains.
- AC-019 is verified by LiveView tests for the shared Monaco component in YAML mode, pasted/replaced text, syntax/schema/policy feedback, request-body protection, and forged-event server validation.
- AC-020 is verified by tests showing profile load/edit changes only socket working-copy state and leaves release assets unchanged.
- AC-025 is verified by a database concurrency test in which multiple nodes/tasks request the same non-concurrent policy key and exactly one claim reaches execution.
- AC-028 is verified by route, event, and direct-request tests for unauthenticated, learner, instructor, institution-admin, and non-system-admin identities.
- AC-029 is verified by lifecycle tests for chaining rejection, configured expiry, actor logout, and deleted/disabled/invalid targets.
- AC-030 is verified by session/auth tests asserting separate actor and effective-target assigns and dual audit attribution.
- AC-031 is verified by authorization matrix tests, including an administrator target, proving the actor grants no privilege beyond stop.
- AC-043 is verified by profile tests for stable references, collision-safe reserved-domain addresses, seed-deterministic names/progress, and absence of credentials.
- AC-044 is verified by successful-profile summary tests that assert bounded user reference/name/role and section/content slug projections.

## 14. Backwards Compatibility

- The run-history migration is additive and safe while disabled. Existing installations behave unchanged because the capability defaults off and historical records remain inaccessible through new routes while disabled.
- Existing `Oli.Scenarios` test execution remains available. Deployed policy is an adapter and certification layer, not a global restriction on test scenarios.
- New directives extend the DSL without changing existing directive syntax. Parser/schema versioning must retain current scenarios.
- Stagehand repository call sites migrate before its public functions are removed. If a short deprecation interval is needed, wrappers may delegate only to scenario-owned services for local development and must never be callable from deployed seeding paths.
- Existing authorization continues to consume `current_user`; masquerade changes only how that identity is restored from a validated session. Non-masqueraded sessions are unchanged.
- Disabling the capability stops new work and invalidates active masquerade on the next request but preserves run/audit history and scenario-created data.
- The initial API adds only a read-only endpoint; there is no compatibility commitment for remote execution because no trigger endpoint is introduced.

## 15. Risks & Mitigations

- Deployed scenarios become arbitrary execution: use a closed catalog, full-tree preflight policy, strict schemas, no custom includes/hooks, and a minimal certified directive/assertion allowlist.
- Retries duplicate domain data: combine policy claims, Oban uniqueness, stable identities/references, handler reconciliation, conditional run transitions, and explicit partial-failure reporting.
- Seed workload exhausts preview resources: serialize the queue, bound internal concurrency and summaries, preload shared inputs, throttle progress writes, and observe workload before setting hard limits.
- Custom YAML persists through infrastructure: exclude it from history/logging and prefer encrypted ephemeral payload storage with terminal deletion and orphan pruning; document database/Oban retention implications.
- Masquerade leaks administrator privilege: keep actor and target separate, feed only target into ordinary authorization, make stop the only actor exception, and test forged requests across representative surfaces.
- Banner is absent from an application shell: centralize it in authenticated root layouts and maintain a layout coverage matrix for server, LiveView, and React-mounted routes.
- External side effects reach real services: make enabled-deployment manifest validation a rollout gate and verify payment, email, LTI, and other approved integrations are disabled or redirected independently of session state.
- Startup errors are invisible because readiness remains healthy: persist configuration/terminal state and alert on configured-profile failure or prolonged queue age without failing application health.
- Existing assertions mutate indirectly: certify assertions individually with tests and start with the smallest required set; reject all others.

## 16. Open Questions & Follow-ups

- Confirm the existing purpose-authentication mechanism and credential scope that the Playwright status endpoint will reuse.
- Choose and document the deployment configuration keys used to resolve the explicit seed-owner author and institution.
- Finalize the initial deployed-safe directive and assertion allowlists after mapping the two profile definitions to existing handlers.
- Decide during detailed design whether encrypted Oban args meet retention requirements or a short-lived encrypted payload table is required for custom YAML transport; either option must preserve the no-history contract.
- Inventory authenticated root layouts and external integrations as implementation checklists so banner coverage and QA containment are verifiable rather than assumed.

## 17. References

- `docs/exec-plans/current/preview-environment-tooling/prd.md`
- `docs/exec-plans/current/preview-environment-tooling/requirements.yml`
- `ARCHITECTURE.md`
- `harness.yml`
- `docs/STACK.md`
- `docs/TOOLING.md`
- `docs/TESTING.md`
- `docs/PRODUCT_SENSE.md`
- `docs/FRONTEND.md`
- `docs/BACKEND.md`
- `docs/DESIGN.md`
- `docs/OPERATIONS.md`
- `docs/CODEREVIEW.md`
- `docs/ISSUE_TRACKING.md`
- `docs/design-docs/high-level.md`
- `docs/design-docs/publication-model.md`
- `docs/design-docs/scoped_feature_flags.md`
- `lib/oli/scenarios.ex`
- `lib/oli/scenarios/`
- `lib/oli/utils/stagehand.ex`
- `lib/oli/utils/stagehand/`
- `lib/oli/application.ex`
- `lib/oli_web/router.ex`
- `lib/oli_web/live/common/monaco.ex`
- `assets/src/hooks/monaco_editor.tsx`
