# Preview Environment Seeding and User Masquerade - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/features/preview-environment-tooling/prd.md`
- FDD: `docs/exec-plans/current/features/preview-environment-tooling/fdd.md`
- Requirements: `docs/exec-plans/current/features/preview-environment-tooling/requirements.yml`
- Course simulation design: `docs/exec-plans/current/features/preview-environment-tooling/design/course-progress-simulation.md`

## Scope

Deliver a production-shaped `MIX_ENV=preview` release with three coordinated capabilities: a synchronous `bin/seed` interface for scenario execution and project ingestion, system-administrator user masquerade for manual QA, and non-delivering preview email with a protected mailbox. Extend `Oli.Scenarios` with deterministic bulk-user and learner-progress operations, provide an idempotent bundled `review_demo` profile, and connect that profile to the post-migration Kubernetes workflow.

The implementation must preserve the non-production scenario-seeding boundary, the deployable preview boundary and deny-by-default runtime activation, existing publication and authorization boundaries, existing Playwright-owned scenario setup, and the ordinary production release default. It must not add a production seeding entry point, seed UI or general HTTP API, Oban seed work, seed-run persistence, YAML snapshots, broad external-integration suppression, or a claim that unsanitized production database clones are safe.

## Clarifications & Default Assumptions

- Scenario seeding is supported in `dev`, `test`, and `ci_e2e` through existing local or token-protected Playwright interfaces and in `preview` through the privileged release CLI; `prod` exposes no supported seeding entry point. `MIX_ENV=test` may compile `preview/lib` solely for automated verification, while `MIX_ENV=preview` is the deployable preview capability boundary. `PREVIEW_QA_TOOLS_ENABLED` activates compiled preview seeding, masquerade, and mailbox access only when its value equals `true` case-insensitively; whitespace-padded and all other values remain disabled.
- While masquerade is active, normal application authorization has exactly the target user's capabilities. No general system-administrator route, LiveView, API, navigation, data access, or mutation may authorize from the actor identity. The only actor-authorized exceptions are stopping masquerade and accessing the preview mailbox at `/dev/mailbox`.
- `config/preview.exs` is standalone and intentionally duplicates only applicable production-shaped settings. It imports neither `prod.exs` nor `dev.exs`.
- Preview email always uses `Swoosh.Adapters.Local`, independently of runtime activation. Other outbound integrations remain unchanged and require fresh or explicitly sanitized data plus non-production credentials.
- Shell or IEx access is the authorization and audit boundary for seeding. The CLI exposes the complete existing scenario DSL and is not an input sandbox.
- CLI scenario execution adds an explicit-ownership mode without changing the defaults used by existing tests and Playwright. Author and institution must be established in YAML before an ownership-dependent directive executes.
- Scenario and ingest operations retain their existing transaction boundaries. Once scenario execution begins, a failure may leave partial mutations and must say so without claiming rollback.
- Deployment manifests may be owned outside this repository. If implementation confirms that boundary, the Torus change must define and test the command contract and provide the exact manifest change for the owning deployment repository; the phase gate requires evidence that the owning deployment path was updated before rollout.
- No Jira write is part of this plan. If delivery tracking requires Jira changes, draft the exact proposed changes and obtain explicit user approval before using the `jira` CLI.
- Phase 4B expands course simulation before Phase 5 consumes it. Its initial profile mode targets learners without existing section progress and supports fast execution by default or optional real-time pacing sampled independently per learner from profile timing distributions, without a target duration window. Operators can stop the separate CLI process and preserve all committed learner progress. Backdated history is deferred. Phase 5 must resolve reconciliation of complete and interrupted simulation runs before its retry-safe deployment gate can pass.

## Phase 1: Establish the Preview Build and Runtime Safety Boundary

- Goal: Make preview a production-shaped release environment whose QA capabilities are compile-time isolated, runtime-disabled by default, and incapable of external email delivery.
- Requirements: FR-001, FR-010; AC-001, AC-002, AC-003, AC-004, AC-025.
- Tasks:
  - [x] Audit every `Mix.env()` branch and dependency `only:` selector that affects release construction or behavior, including `mix.exs`, `config/config.exs`, `lib/oli_web/endpoint.ex`, Gleam compiler paths, permanent startup, static compression, and release-only dependencies; record which branches must treat `:preview` as production-like.
  - [x] Add standalone `config/preview.exs` with the applicable production-shaped endpoint, logging, Playwright, and release settings, an immutable preview build marker, and `Oli.Mailer` configured with `Swoosh.Adapters.Local`.
  - [x] Add `Oli.PreviewQATools.Config` as the single effective-enablement boundary, combining the compile-time preview marker with strict runtime parsing of `PREVIEW_QA_TOOLS_ENABLED`.
  - [x] Wire application startup to emit one bounded instructional warning for a preview build whose runtime activation is disabled and one bounded enabled signal when active; emit neither message for other Mix environments.
  - [x] Parameterize the Docker build and all release-stage paths with `ARG MIX_ENV=prod`; propagate the selected environment consistently through dependency resolution, asset/release compilation, and final-stage copies.
  - [x] Update both jobs in `.github/workflows/build-preview-image.yml` to pass `MIX_ENV=preview`, while leaving production image callers on the safe default.
  - [x] Update `guides/process/building.md` with the purposes, scenario-seeding boundaries, and workflows for `dev`, `test`, `ci_e2e`, `preview`, and `prod`, standalone preview configuration ownership, compile-time versus runtime configuration, activation syntax, local-email containment, and the unsupported production-clone boundary.
- Testing Tasks:
  - [x] Add unit tests for the full environment/flag truth table, including casing variants and missing, blank, whitespace-padded, false, malformed, hostname, profile, and unrelated-flag inputs.
  - [x] Capture logs to prove the preview-disabled warning is emitted once and other environments do not emit it.
  - [x] Add configuration assertions that preview uses `Swoosh.Adapters.Local` whether the runtime flag is enabled or disabled.
  - [x] Add static environment-policy, workflow, and Docker assertions for trusted seeding in `dev`, `test`, `ci_e2e`, and `preview`; explicit production exclusion; the `prod` Docker default; both preview build arguments; and consistent environment-specific release paths.
  - [x] Compile or build the preview release through the existing preview-image path and retain existing production packaging as the production-environment gate.
  - Command(s): `mix test <targeted PreviewQATools configuration and build-policy tests>`; `MIX_ENV=preview mix compile`; `mix format`; preview-image workflow build.
- Definition of Done:
  - Preview compiles with production-shaped settings and local-only mail, production remains the Docker default, runtime activation is deny-by-default, startup signals are bounded, and the environment contract is documented.
- Gate:
  - AC-001 through AC-004 and AC-025 have automated evidence; a preview release builds successfully; test-only compilation is distinguished from deployable inclusion; and review confirms production exposes no scenario-seeding route or preview release tooling.
- Dependencies:
  - None.
- Parallelizable Work:
  - Docker/workflow changes, build documentation, and configuration-test scaffolding can proceed in parallel after the environment audit agrees on the production-like branch matrix.

## Phase 2: Build the Synchronous Scenario Release Interface

- Goal: Provide a bounded, release-compatible CLI for listing and synchronously running bundled or operator-provided scenarios with explicit execution ownership.
- Requirements: FR-002; AC-005, AC-006, AC-007, AC-008, AC-009.
- Tasks:
  - [x] Add the environment-neutral `Oli.Seeding.CLI` dispatcher, a development-only `mix seed` task, and the preview `rel/overlays/bin/seed` wrapper following the existing `rel/overlays/bin/migrate` pattern; exclude seeding code from production builds and fail preview execution before mutation unless effective preview enablement is active.
  - [x] Implement strict argument parsing for `scenarios list` and `scenarios run --name <id>|--file <path>`, rejecting missing values, unknown options, extra arguments, and non-exclusive sources with bounded usage output and deterministic nonzero status.
  - [x] Define an application-owned bundled-scenario registry and immutable release asset location with stable identifier, description, and version or digest metadata; listing must read metadata without parsing or executing scenario bodies.
  - [x] Add an `Oli.Scenarios` execution adapter that preserves `use`, assertions, hooks, and the complete DSL while enabling explicit-ownership validation only for release execution.
  - [x] Support ownership through created scenario references, restricted unique lookup, and explicit configured defaults such as `default_admin`; reject missing, late, ambiguous, inactive, or wrong-type author/institution selection before the first dependent mutation.
  - [x] Emit bounded structured operation, source, identifier/digest, duration, aggregate-count, result-code, and partial-mutation fields without YAML bodies, credentials, responses, or secrets.
  - [x] Keep the dispatcher callable from IEx and avoid any web route, application role check, Oban worker, queue, run record, YAML snapshot, retry manager, or deployed-safe directive allowlist.
- Testing Tasks:
  - [x] Test scenario listing metadata and prove list does not parse or execute bundled YAML.
  - [x] Test the argument matrix, deterministic exits, bounded output, disabled-state failure before mutation, and partial-mutation reporting after execution begins.
  - [x] Run bundled and temporary local YAML through the dispatcher, including `use` composition, assertions, and hooks.
  - [x] Test each accepted ownership mechanism and all ordering, ambiguity, activity-state, and type failures; prove legacy scenario defaults remain unchanged outside release mode.
  - [x] Add negative structural checks for seed HTTP routes, application authorization, Oban seed modules/queues, persistence schemas, and extra DSL allowlists.
  - Command(s): `mix test <release dispatcher, bundled registry, and scenario ownership tests>`; `mix format`.
- Definition of Done:
  - `mix seed` in development and `bin/seed` in an enabled preview release execute through the same synchronous dispatcher, expose the full scenario engine, enforce YAML-defined ownership, redact sensitive input, and return reliable status without new application-managed state; production compiles neither entry point.
- Gate:
  - AC-005 through AC-009 pass, including a release-overlay smoke test and regression coverage for existing scenario execution.
- Dependencies:
  - Phase 1 effective-enablement and preview-release boundaries.
- Parallelizable Work:
  - Bundled registry/release packaging, CLI parsing/output, and scenario explicit-ownership support can be developed concurrently behind agreed dispatcher and result interfaces.

## Phase 3: Add Bounded Project Archive Ingestion

- Goal: Extend `bin/seed` with safe, synchronous HTTP/HTTPS archive download and ingestion through the existing domain boundary.
- Requirements: FR-003; AC-010, AC-011.
- Tasks:
  - [x] Add `projects ingest --url <http(s)-url> --author default_admin|email:<email>` parsing and explicit unique active-author resolution.
  - [x] Implement `Oli.Seeding.ProjectIngest` with HTTP/HTTPS-only scheme validation, finite connection/receive timeouts, bounded redirects, configured maximum bytes, and streaming into a uniquely created temporary directory.
  - [x] Invoke `Oli.Interop.Ingest.ingest/2` without reimplementing archive import, and report only the bounded identity of the created project.
  - [x] Guarantee temporary-file and directory cleanup in success, download failure, size/redirect/timeout failure, invalid archive, author failure, and ingest failure paths.
  - [x] Sanitize errors and telemetry so URL credentials, query secrets, response bodies, archive contents, and author-sensitive values do not reach routine logs.
- Testing Tasks:
  - [x] Cover HTTP and HTTPS acceptance, invalid schemes, redirects and redirect loops, receive failures/timeouts, exact/oversized byte limits, truncated downloads, and non-success status codes through the downloader's controlled response boundary.
  - [x] Test author selection, successful `Oli.Interop.Ingest` integration, ingest failures, deterministic exit status, bounded result output, and cleanup after every outcome.
  - [x] Capture logs for credential and archive-content redaction and verify network-policy ownership is documented without adding an application SSRF destination allowlist.
  - Command(s): `mix test <project ingest and release CLI ingest tests>`; `mix format`.
- Definition of Done:
  - The enabled preview CLI ingests a reachable archive through `Oli.Interop.Ingest`, bounds all local resource use described in the FDD, cleans up reliably, and reveals no sensitive URL or archive data.
- Gate:
  - AC-010 and AC-011 pass with success and forced-failure cleanup evidence.
- Dependencies:
  - Phase 1 and the Phase 2 dispatcher/result contract.
- Parallelizable Work:
  - The downloader and its controlled-server tests can proceed alongside Phase 2 scenario ownership work once the common CLI result contract is fixed.

## Phase 4: Move Bulk Users and Progress Simulation into Oli.Scenarios

- Goal: Replace the separate Stagehand execution path with deterministic, reusable scenario directives that preserve domain and performance boundaries.
- Requirements: FR-004; AC-012, AC-013, AC-014.
- Tasks:
  - [x] Define and document `bulk_create_enroll_users` and `simulate_progress` directive schemas, validation, stable-reference rules, optional random seed behavior, structured warnings, and failure semantics.
  - [x] Extract reusable enrollment and progress behavior from `lib/oli/utils/stagehand.ex` and its supporting modules into scenario-owned services using existing account, section, enrollment, attempt, and evaluation contexts.
  - [x] Implement collision-safe synthetic instructor/learner identities and deterministic reference generation that remains stable across a seeded retry.
  - [x] Implement progress simulation using preloaded section inputs, fixed-size batches, modest supervised concurrency, and bounded per-task timeouts; aggregate unsupported activity/content warnings without unbounded learner detail.
  - [x] Register parser, validator, directive type, handler, and documentation support using the established `Oli.Scenarios` extension points.
  - [x] Migrate repository Stagehand call sites to scenario-owned behavior, then remove the standalone deployed Stagehand API and dead helper state after parity is proven.
- Testing Tasks:
  - [x] Add parser/validator tests plus integration scenarios for valid and invalid attributes, role/enrollment creation, stable references, identity collisions, deterministic seeded progress, and different-seed variation.
  - [ ] Cover supported activity completion, grading/progress results, unsupported content warnings, task timeout/failure aggregation, and bounded concurrency without N+1 section loading. (Deterministic integration coverage requires a runner outside the existing Ecto sandbox transaction because attempt setup changes transaction isolation.)
  - [x] Run affected existing Stagehand and scenario suites before removal, then add a repository check proving no separate deployed Stagehand call path remains.
  - Command(s): `mix test <bulk_create_enroll_users, simulate_progress, and migrated Stagehand tests>`; `mix test test/scenarios`; `mix format`.
- Definition of Done:
  - Both directives are normal scenario operations with deterministic references and bounded execution, all call sites use scenario-owned behavior, and Stagehand is no longer an independent deployed interface.
- Gate:
  - AC-012 through AC-014 pass, existing scenario behavior remains green, and performance review confirms batching, preloading, concurrency, and output bounds.
- Dependencies:
  - Phase 2 establishes release execution and explicit ownership; directive service extraction itself may start after the relevant scenario extension points are confirmed.
- Parallelizable Work:
  - `bulk_create_enroll_users` and `simulate_progress` can be implemented in parallel with shared agreement on reference generation, warning/result structures, and deterministic random-state handling.

## Phase 4B: Implement Profile-Driven Course Progress Simulation

- Goal: Take enrolled learner cohorts through a delivered course with varied participation, realistic practice retries, repeated scored assessments, and improving performance. Replace the existing Phase 4 progress-simulation examples with this supported workflow, supplying learner data for Phase 5 while preserving focused legacy syntax coverage.
- Requirements: FR-004, FR-005; AC-012, AC-013, AC-016. Detailed behavior and proposed acceptance additions are specified in `docs/exec-plans/current/features/preview-environment-tooling/design/course-progress-simulation.md`.
- Tasks:
  - [ ] Reconcile the detailed design's course-simulation acceptance additions into `requirements.yml`, PRD, and FDD before implementing the new contract; retain Phase 4's legacy directive and result compatibility requirements.
  - [ ] Establish `Oli.Seeding.Runtime` and a dedicated seeding application role for both development `mix seed` and preview `bin/seed` before implementing the runner. Audit/start required Repo, caches, evaluators, job producers, and event infrastructure without the HTTP endpoint, unrelated consumers/plugins, upload pipelines, or inventory/startup recovery. Do not start the full app temporarily. Separate consumer disablement from snapshot enqueue semantics, verify cross-VM cache/event behavior, and document refresh/readiness guarantees instead of assuming local PubSub reaches the server.
  - [ ] Add a terminal interrupted outcome through the handler, Engine (including nested `use` and non-ownership loops), `SeedExecution`, CLI, and Mix wrapper. Stop all remaining directives, retain bounded partial results, preserve SIGINT/SIGTERM statuses 130/143, and avoid generic rescue/catch or `Mix.raise` rewriting cancellation as failure. Own workers/timers under the invocation; stop dispatch immediately, allow at most five seconds for in-flight atomic work, and terminate workers on parent death without affecting the server or its committed-action jobs.
  - [ ] Extract shared scenario-owned learner operations for visiting, starting, saving, submitting, resetting activities/parts, requesting hints, and finalizing attempts. Reuse them from applicable existing directive handlers and the simulator, with explicit learner/session context and no generated YAML orchestration or implicit enrollment during simulation.
  - [ ] Implement native response adapters for multiple choice, ordering, check-all-that-apply, short answer, and multi-input using actual part identities and the current full transformed model. Generate UI-valid responses, obtain scores through real evaluation, and report unsupported rules/configurations without fabricated answers or direct score writes.
  - [ ] Implement practice retry flows matching delivery behavior: whole-activity reset for applicable activities and per-part reset for multi-input with `submitPerPart`. Consume returned attempt identities, preserve the page attempt, honor limits/hints/replacement rules, and stop at the configured target or persistence limit.
  - [ ] Implement batch-scored assessment participation through start, save, and finalize, then use actual resulting scores to decide on new assessment attempts. Respect grading strategy, attempt limits, gating, dates, passwords, and learner settings; explicitly report unsupported scoring modes until their delivery adapters are covered.
  - [ ] Add versioned `high_proficiency`, `steady_learner`, `persistent_learner`, and `low_engagement` profiles with validated overrides separating correctness, course reach, participation, persistence, hint use, attempt caps, targets, and learning gain.
  - [ ] Extend directive type, parser, validator, JSON schema, handler, and documentation together for `profile`, `profile_version`, `overrides`, and `cohorts`. Support explicit learner membership or deterministic count-based assignment; validate the entire population before mutation and reject ambiguous profile/legacy combinations.
  - [ ] Add optional `timing: {mode: paced}` to profile mode, with fast execution as the default and no total-duration window. Add profile timing distributions and `overrides.timing` for start delays, page residence, answering time, retry delays, occasional breaks, session lengths, and session gaps. Validate bounded triangular distributions and reject malformed values, duration-window options, and partial scenario-time overrides.
  - [ ] Implement an invocation-local scheduler with independently seeded learner journeys, staggered starts, reading/answering/retry delays, profile-dependent sessions/breaks, and sampled activity skips. Interleave due actions across all learners, allow one action in flight per learner, retain bounded dispatch/concurrency, and release workers and database resources during waits. Sample future actions from actual outcomes and enforce minimum page residence and retry delays from actual execution times, including under scheduler lag.
  - [ ] Support long-running paced CLI execution in a separate shell alongside the server, with bounded progress/lag output and completion only when learner policies finish or the operator stops the command. On interruption, cancel all pending simulation work and shut down owned workers without additional learner mutations or executing subsequent directives; preserve committed progress and keep the web server running. Document bounded in-flight transaction shutdown, conventional interrupted status, and continuing server-owned jobs for already committed actions; add no detached learner workers, seed-specific Oban scheduling, durable run state, or automatic resume.
  - [ ] Implement a pure seeded policy and per-learner runner that traverses the delivered curriculum in learner order, including section customizations and unnumbered pages, models partial/no participation, and performs bounded remediation before reassessment. Increase correctness probability through relevant learning steps without guaranteeing monotonically increasing observed scores.
  - [ ] Use stable logical identities and separate deterministic decision streams so batching and worker scheduling do not change learner behavior. State the reproducibility boundary for changed publications, imported content, and dynamic transformations; retain the legacy seed behavior for existing explicit scripts.
  - [ ] Preflight profile-mode learners for existing page access/attempt history and reject unsupported reruns before visits. Document the fresh-history contract and hand off reconciliation requirements to Phase 5 without adding seed-run persistence or automatic cleanup.
  - [ ] Bound learner counts, cohorts, attempts, remediation, concurrency, timeout, and output. Add invocation-wide `max_actions` (default 100,000; hard cap 1,000,000), conservative preflight estimation, and an atomic dynamic dispatch budget. Exhaustion stops with explicit partial results. Enforce per-learner active-work budgets in profile mode, excluding paced waiting, in both single-worker and parallel execution; retain legacy timeout semantics and distinguish processed, course-complete, partial, not-started, blocked, and failed outcomes.
  - [ ] Protect downstream work in fast and paced modes: default 10 actions/second (validated range 1–50), burst bounded by concurrency, read-only monitoring of relevant shared downstream queues, pause at 1,000 outstanding jobs and resume at 500 or fewer. Poll at most once per second, pause on observation failure, and terminate after five continuous minutes of overload with partial results. Report throttling/lag and measure overshoot; never reserve/cancel unrelated jobs or run server consumers in the companion CLI.
  - [ ] Keep waiting-learner state compact: IDs, cursor, traits, RNG/action counters, timing, budgets, and bounded retry/objective counters only. Share course inputs once, reload full models only around actions, and discard observations/history after incremental reduction. Establish a measured course-cardinality envelope and reject excess before mutation; target at most 64 MiB scheduler-owned memory for 10,000 logical waiting learners on a fixed small course, excluding shared course/runtime baseline.
  - [ ] Replace `test/oli/scenarios/data/progress_simulation.scenario.yaml` in place with the supported 40-learner mixed-cohort workflow, retaining two ungraded pages before the assessment and native activity coverage, and adding objective links/retry policies. Replace its old explicit simulation blocks rather than running both on the same learners. Rewrite `test/oli/scenarios/progress_simulation_scenario_test.exs` for profile-driven outcomes, preserve exact legacy compatibility in focused tests, and leave `Oli.Scenarios.Hooks.create_bulk_users/1` and its example intact. Update scenario/CLI docs to this canonical path and provide a paced variant sharing the course setup. Keep analytics readiness explicit and advertise execution-time data rather than historical fidelity.
- Testing Tasks:
  - [ ] For both actual CLI entry points, prove isolated boot alongside the server: no duplicate endpoint/consumers/recovery, an unrelated executing inventory batch is untouched, required services and normal downstream enqueueing work, and server-visible cache/data behavior remains correct. This is a prerequisite gate for long-running simulation.
  - [ ] Test SIGINT/SIGTERM through dev/release wrappers during idle and in-flight states, abrupt parent death, nested `use`, and non-ownership Engine execution. Verify 130/143 where graceful handling applies, terminal partial results, no later directives, bounded shutdown, and an unaffected running server.
  - [ ] Cover parser/schema parity for valid profiles/cohorts/overrides and invalid ranges, names, versions, duplicate membership, cardinality mismatches, missing learners, and legacy-option conflicts.
  - [ ] Test pure participation, retry, learning, and stopping decisions with stable identities; compare normalized outcomes across batch sizes and concurrency levels. Use exact policies for guaranteed QA states and a larger fixed population for probabilistic behavior instead of brittle score-order assertions on tiny cohorts.
  - [ ] Test fast defaults and paced timing validation, bounded delay distributions, independent learner journeys/skips, session breaks, learner interleaving, idle-resource release, active-work timeouts, natural completion, and backpressure with a controlled scheduler clock. Verify minimum page residence/retry intervals survive scheduler lag and no duration cutoff is imposed. Add short real-time and process-level interruption checks proving separated persistence timestamps, retained partial attempts, no later simulated actions or subsequent directives, and continued server availability; manually smoke-test a longer run without making CI wait hours.
  - [ ] Add real scenario integration coverage for all five native types and both multi-input submission modes, verifying activity/part attempt histories, actual scores, hints, page-attempt preservation, and progress semantics without fixtures, factories, or mocks.
  - [ ] Verify repeated scored assessments, save/finalize behavior, and best/latest/average grade aggregation. Cover remediation and prove the simulator does not overwrite grades to achieve a target.
  - [ ] Cover course ordering, partial/no participation, learner access restrictions, existing-history rejection, unsupported content, transformations, stale attempts, exhausted limits, timeout, and partial failure reporting; capture intentional logs.
  - [ ] Run legacy single-`pct_correct`, explicit `assessment_attempts`, and affected lower-level directive suites to prove compatibility. Use an appropriate serializable sandbox setup for lifecycle integration tests.
  - [ ] Validate and execute the mixed-cohort example through development `mix seed` and preview `bin/seed`; inspect normal learner histories, practice progress, instructor gradebook, and explicitly supported analytics after readiness checks.
  - [ ] Test action-budget rejection/exhaustion, rate limits, queue high/low-water hysteresis, queue-observation failure, overload termination, and unaffected unrelated jobs with a controlled clock. Benchmark retained state for 10,000 logical learners across many completed actions and increasing course cardinality; no database fixture population is required for this scheduler benchmark.
  - [ ] Measure full-process memory, bounded work, shared-input query behavior, queue growth/overshoot, and server responsiveness on the replacement 40-learner example, including pre-existing downstream backlog; complete security, performance, and Elixir review before the gate.
  - Command(s): `mix compile`; `mix test test/oli/scenarios/progress_simulation_test.exs test/oli/scenarios/progress_simulation_scenario_test.exs test/oli/scenarios/data_generation_directives_test.exs`; `mix test test/scenarios/validation test/scenarios/directives`; targeted new runtime/cancellation/policy/runner/load tests; `Oli.Scenarios.validate_file/1` for the example; `mix seed scenarios run --file test/oli/scenarios/data/progress_simulation.scenario.yaml` in development and `bin/seed scenarios run --file <staged-progress-simulation.scenario.yaml>` in an enabled preview (stage the canonical source fixture; do not assume release images contain `test/`); `mix format`; `git diff --check`.
- Definition of Done:
  - A supported scenario generates varied learner participation and real practice/assessment histories through shared delivery operations, either quickly by default or at independently randomized profile-defined real-time paces without a total-duration target. The CLI can run alongside the server and be stopped without losing committed progress or leaving simulated learners running. Profiles and scheduled decisions are deterministic within documented bounds, legitimate partial participation and operator interruption are distinct from learner failure, and legacy explicit scripts remain compatible. Backdated history and resumable reruns are explicitly excluded from this phase's capability claim.
- Gate:
  - AC-013 and the mapped course-simulation acceptance additions have passing evidence; the replacement Phase 4 mixed-cohort scenario passes dev/preview execution and UI inspection. Native lifecycle fidelity, isolated companion runtime, invocation-wide interruption, bounded downstream load, compact waiting state, fast/paced execution, and legacy compatibility all have passing evidence. Phase 5 can consume the simulator, but deployment retry safety remains a Phase 5 gate.
- Dependencies:
  - Phase 4's scenario services and directive contract; Phase 2's CLI and explicit ownership; Phase 1's enabled preview release for release-level verification.
- Parallelizable Work:
  - Resolve companion-runtime and cancellation contracts first. After agreeing on learner-operation and observation contracts, pure profile/policy logic can proceed alongside native-response/lifecycle adapters. Cohort wiring and replacement-example authoring follow those contracts; integration, retained-state, and downstream-load verification follow the runner.

## Phase 5: Deliver the review_demo Profile and Deployment Job Contract

- Goal: Create a retry-safe representative QA dataset and invoke it through the same CLI after migrations without coupling Torus readiness or persistence to Kubernetes.
- Requirements: FR-005, FR-006; AC-015, AC-016, AC-017, AC-018.
- Tasks:
  - [ ] Author the immutable bundled `review_demo` scenario using Phase 4B's supported course simulation, with explicit author/institution establishment and stable synthetic references covering authoring, publication, product, section, enrollment, learner progress, gradebook, discussion, gating, and analytics states without embedded credentials.
  - [ ] Keep deployment initialization fast by default. Document paced scenarios as an explicit operator choice with a suitable process/Job lifetime; do not implicitly make the post-migration seed Job run for hours or days.
  - [ ] Make profile operations reconciliation-aware so a Kubernetes retry converges on the intended state rather than silently duplicating projects, users, sections, enrollments, or learner results.
  - [ ] Design and implement a reconciliation strategy for completed and interrupted learner simulation using canonical domain state, compatible with Phase 4B's fresh-history default and the prohibition on seed-run persistence. Specify how completed work is recognized and partial work is continued; do not treat a deterministic seed or an existing enrollment as proof that learner progress is complete.
  - [ ] Add deployment configuration that omits the seed Job when `PREVIEW_QA_SEED_PROFILE` is absent and creates it only after successful migrations when present.
  - [ ] Pass the resolved profile as a discrete final argument to `bin/seed scenarios run --name <profile>` without shell interpolation; use `seed-<profile>-<release-id>`, application/environment/release/profile/component labels, `restartPolicy: Never`, `backoffLimit: 1`, and explicit CPU/memory requests and limits initially matching the migration Job.
  - [ ] Preserve Kubernetes ownership of stdout/stderr, exit observation, one retry, Job status, resource visibility, and the existing retention convention; add no Torus startup coordinator, Job API client, readiness dependency, or Job identity/history storage.
  - [ ] Audit Playwright's test-only controller, fixtures, token, and per-spec identifiers and leave their self-seeding lifecycle independent of `review_demo` and any startup-status endpoint.
- Testing Tasks:
  - [ ] Execute `review_demo` through the release dispatcher and assert every representative domain state plus absence of credentials in source and logs.
  - [ ] Execute the profile twice and verify reconciliation and stable references do not introduce unintended duplicates.
  - [ ] Interrupt simulation after some learner actions have committed, rerun the deployment profile, and verify convergence without duplicated attempts or skipped incomplete learners. Keep this test mandatory before enabling the Kubernetes retry contract.
  - [ ] Add static or rendered-manifest tests for omission/presence, migration ordering, discrete arguments, name/labels, restart policy, retry limit, resources, logs/retention ownership, and lack of readiness coupling.
  - [ ] Run the existing Playwright scenario-fixture tests and add a contract check proving they reference neither `review_demo` nor a startup-status endpoint.
  - [ ] Add negative repository checks for an Oban seed job/queue, seed-run schema or migration, startup-status route, and persistent execution history.
  - Command(s): `mix test <review_demo and deployment-contract tests>`; `<existing Playwright fixture test command>`; `mix format`; rendered deployment-manifest validation in the owning repository.
- Definition of Done:
  - `review_demo` creates the approved synthetic state through `bin/seed`, converges under the configured retry, the post-migration Job meets the operational contract, and Playwright remains independently self-seeding.
- Gate:
  - AC-015 through AC-018 pass, including completed-run and interrupted-run learner reconciliation; deployment ownership and rollout evidence are identified; the Job does not affect application readiness.
- Dependencies:
  - Phases 2, 4, and 4B; Phase 1's preview image is required for end-to-end Job execution.
- Parallelizable Work:
  - Profile authoring, deployment manifest work, and Playwright regression auditing can proceed concurrently once the CLI and directive contracts stabilize.

## Phase 6: Implement Secure Masquerade Identity and Session Lifecycle

- Goal: Let an enabled current system administrator act as an active delivery user while preserving actor accountability, target-only authorization, and fail-closed lifecycle behavior.
- Requirements: FR-007, FR-008; AC-019, AC-020, AC-021, AC-022.
- Tasks:
  - [ ] Add preview-compiled `Oli.PreviewQATools.Masquerade` start, restore, stop, expiry, and invalidation services with effective-enablement checks and system-administrator authorization at every actor-sensitive boundary.
  - [ ] Store only bounded actor ID, target ID, issued/expiry timestamps, and random session reference in the existing tamper-protected signed session; renew the session on start and make no application-wide encryption or active-session-table change.
  - [ ] Restrict targets to active delivery users, reject self/chained masquerade, revalidate actor, target, flag, expiry, and signed state on every restoration, and clear invalid state safely.
  - [ ] Install only the target as `current_user` across plugs, LiveView mounts, sockets, controllers, APIs, policies, context calls, and rendered navigation; never retain or expose an actor-derived admin role, permission set, current-author identity, or privileged assign while masquerade is active.
  - [ ] Keep actor identity in a separately named, private session/audit representation that no general authorization function accepts. Expose it only to audit emission and two dedicated authorization boundaries: stopping masquerade and accessing the preview mailbox at `/dev/mailbox`.
  - [ ] Add start to the existing system-admin user detail surface and add a CSRF-protected stop boundary with safe allowlisted return destinations.
  - [ ] Clear or reject masquerade on explicit stop, logout, expiry, target invalidation, runtime disablement, and entry into a fresh LTI login/launch identity flow.
  - [ ] Emit `Oli.Auditing` lifecycle events for start, stop, expiry, and invalidation with actor, target, timestamp, session reference, reason, and bounded request context; follow existing fail-closed behavior for required audit failures.
- Testing Tasks:
  - [ ] Add service, controller/LiveView, session-restoration, and forged-request tests for disabled/non-preview states, anonymous/non-admin actors, inactive/non-delivery targets, chaining, expiry, tampering, target invalidation, logout, flag changes, and LTI entry.
  - [ ] Test safe destination allowlisting and CSRF enforcement for start and stop.
  - [ ] Verify representative target-authorized reads and writes succeed as the target and persist with target-user authorization semantics, while audit records consistently retain both identities.
  - [ ] Exercise system-admin controllers, LiveViews, APIs, navigation links, and privileged mutations while masquerading as a non-admin target; assert they are absent or denied exactly as they would be for that target when signed in directly, excluding only `/dev/mailbox`.
  - [ ] Add an authorization regression matrix comparing a direct target session with an admin-masquerading-as-target session and require identical capability decisions everywhere except the dedicated stop endpoint/control and preview mailbox route.
  - [ ] Prove actor identity cannot be passed to ordinary policy/context authorization and that forged requests cannot invoke any actor-authorized action outside the stop and mailbox boundaries.
  - [ ] Capture intentional audit/log output and prove session state contains only the bounded signed identifiers and timestamps.
  - Command(s): `mix test <masquerade service, auth/session, admin user detail, audit, and LTI boundary tests>`; `mix format`.
- Definition of Done:
  - Masquerade is preview-compiled, runtime-gated, system-admin initiated, non-chainable, expiring, auditable, safely stoppable, and capability-equivalent to signing in directly as the target user, except for the narrowly isolated actor-authorized stop and preview-mailbox capabilities.
- Gate:
  - AC-019 through AC-022 pass with direct-versus-masqueraded target capability parity, explicit denial of every sampled general admin surface and mutation, tamper/lifecycle evidence, and security-review confirmation that actor privilege is reachable only at stop and `/dev/mailbox`.
- Dependencies:
  - Phase 1 effective-enablement and compile boundary.
- Parallelizable Work:
  - Audit event design, signed-session lifecycle, and system-admin surface integration can proceed concurrently after the session payload and service interface are agreed.

## Phase 7: Add Persistent Masquerade UI and Protected Mailbox Access

- Goal: Make active masquerade unmistakable and immediately reversible across authenticated shells, and expose captured preview email only to enabled current system administrators, including a valid original admin actor during masquerade.
- Requirements: FR-009, FR-010; AC-023, AC-024, AC-026.
- Tasks:
  - [ ] Add `OliWeb.Components.MasqueradeBanner` with the target's identity, explicit “acting as” wording, high-contrast magenta styling, non-color warning cues, a keyboard-operable CSRF-protected stop control, and screen-reader labels/status semantics.
  - [ ] Integrate the banner once per authenticated root across `default`, `workspace`, `delivery`, `delivery_student_dashboard`, `delivery_dashboard`, authenticated LiveView, and authenticated `chromeless` surfaces without changing unauthenticated layout behavior.
  - [ ] Keep `delivery_from_payment` and `lti` layouts banner-free, relying on the Phase 6 LTI identity-boundary clearing/rejection behavior.
  - [ ] Compile `/dev/mailbox` only for preview, consolidate the existing development/test mailbox declaration under one policy, and place `Plug.Swoosh.MailboxPreview` behind `:browser`, effective runtime enablement, and a dedicated mailbox authorization plug that accepts either the current system administrator or the original system-administrator actor of a valid active masquerade.
  - [ ] Keep the mailbox exception route-local: authorize from the actor identity only inside the dedicated mailbox plug, do not replace `current_user`, do not expose actor privileges to the mailbox plug's downstream general authorization helpers, and do not reuse this exception for any other admin route.
  - [ ] Return a non-disclosing response for disabled, unauthenticated, non-admin, expired, or invalid-session mailbox requests and prevent message metadata from entering application telemetry.
- Testing Tasks:
  - [ ] Add a layout matrix test proving exactly the required authenticated surfaces render one banner and that `delivery_from_payment`, `lti`, unauthenticated, disabled, and ordinary sessions do not.
  - [ ] Test visible target identification, non-color wording/iconography, focus order, keyboard activation, accessible name/status semantics, color contrast, responsive placement, and stop behavior.
  - [ ] Test mailbox compile/runtime/auth truth tables for preview and non-preview builds, including anonymous, author, ordinary user, stale-admin, current system-admin, admin masquerading as a non-admin target, and non-admin-originated or forged masquerade requests.
  - [ ] Prove a valid admin actor can access `/dev/mailbox` while masquerading, the request still retains the target as `current_user`, and adjacent or representative system-admin routes remain denied in the same session.
  - [ ] Send representative email in preview with activation both on and off, prove it remains local, and verify only an enabled current system administrator or valid original admin actor during masquerade can inspect it.
  - Command(s): `mix test <masquerade component/layout and mailbox route tests>`; `mix format`; targeted manual keyboard and screen-reader check.
- Definition of Done:
  - Every required authenticated surface communicates masquerade accessibly and offers immediate stop, excluded identity/payment layouts remain unchanged, preview mail cannot leave through `Oli.Mailer`, and mailbox contents are available to a current admin or valid masquerading admin actor but non-disclosing to every other state.
- Gate:
  - AC-023, AC-024, and AC-026 pass; UI/accessibility and security reviews approve the complete layout and mailbox matrices.
- Dependencies:
  - Phases 1 and 6.
- Parallelizable Work:
  - Banner component/layout integration and mailbox route/authentication work can proceed in parallel after the shared effective-enablement boundary is stable.

## Phase 8: Integrated Verification, Review, and Rollout Readiness

- Goal: Prove end-to-end behavior, requirement coverage, scope exclusions, operational safety, and maintainability before preview rollout.
- Requirements: FR-001 through FR-010; AC-001 through AC-026.
- Tasks:
  - [ ] Reconcile implementation evidence against every requirement and acceptance criterion in `requirements.yml`, updating proof references without weakening the approved PRD/FDD contract.
  - [ ] Run focused security, performance, Elixir, UI/accessibility, and requirements reviews under `.review/`; include TypeScript or Gleam review only if final changed files require those lenses.
  - [ ] Inspect the final diff for sensitive logging, unbounded output/work, unsafe URL handling, authorization bypass, privilege inheritance, N+1 queries, compile/runtime boundary drift, and undocumented operational assumptions.
  - [ ] Confirm excluded scope remains absent: seed UI/API, Oban seed scheduling, seed history/YAML persistence, startup status, broad external-integration suppression, and production-clone safety claims.
  - [ ] Finalize operator documentation for CLI syntax, synthetic-data responsibility, partial-mutation behavior, profile activation, Job observation/retry ownership, local mailbox access, masquerade lifecycle, and safe disablement.
  - [ ] Execute the manual QA matrix from a preview-built image: list scenarios, run bundled and custom YAML, ingest a controlled archive, run the deployment profile, inspect captured mail, masquerade as instructor and learner across all required shells, stop safely, and confirm disabled/non-preview rejection.
- Testing Tasks:
  - [ ] Run all targeted suites from prior phases, then the broader affected backend and scenario suites.
  - [ ] Run formatting and compile gates, the full preview-image release build, deployment manifest validation, and existing production packaging evidence.
  - [ ] Validate the work-item traceability and plan structure with the Harness scripts.
  - Command(s): `mix test <all affected targeted test files>`; `mix test test/oli/scenarios test/scenarios`; `MIX_ENV=preview mix compile`; `mix format`; `git diff --check`; preview-image workflow build; existing production package/release workflow; Harness requirements and plan validators.
- Definition of Done:
  - All AC-001 through AC-026 have passing automated or hybrid evidence, all required reviews are resolved, manual preview QA passes, documentation matches the shipped interfaces, and excluded application surface remains absent.
- Gate:
  - Final release-readiness review accepts the requirements evidence, preview build, deployment contract, security/performance/accessibility results, and operational rollback of disabling runtime QA tools; no unresolved implementation marker remains.
- Dependencies:
  - Phases 1 through 7, including Phase 4B.
- Parallelizable Work:
  - Review lenses and documentation verification may run concurrently after the implementation diff stabilizes; end-to-end manual QA begins only after all phase gates pass.

## Parallelization Notes

- Phase 1 is the critical-path foundation because all callable capabilities depend on its compile-time and runtime boundary.
- After Phase 1, Phase 2 CLI/scenario ownership and Phase 6 masquerade lifecycle are independent workstreams. Phase 3 can begin once Phase 2 fixes the common CLI result interface.
- Phase 4 directive work can overlap Phases 2 and 3, but its final release tests depend on Phase 2. Phase 4B follows Phase 4 and supplies the course simulation consumed by Phase 5. Deployment manifest work may proceed earlier, but Phase 5's demo-data gate depends on Phase 4B and verified learner reconciliation.
- Phase 7 UI and mailbox work can overlap Phases 2 through 5 but requires the effective-enablement contract from Phase 1 and masquerade state contract from Phase 6.
- Assign one owner to changes in shared scenario parser/validator/runtime files and one owner to shared router/session/layout files to avoid conflicting edits. Integrate each workstream only after its focused gate is green.
- Review and verification tasks should be performed continuously within phases; Phase 8 consolidates evidence rather than postponing security, performance, accessibility, or test work.

## Phase Gate Summary

- Gate A — Environment boundary: trusted scenario seeding is available in `dev`, `test`, `ci_e2e`, and `preview`; `MIX_ENV=preview` builds production-shaped with deny-by-default runtime activation; `MIX_ENV=test` may compile preview sources solely for verification; production exposes no seeding entry point or preview release tooling; and preview email is always local.
- Gate B — Scenario CLI: bundled listing and synchronous bundled/custom execution pass with strict usage, full DSL compatibility, explicit ownership, bounded output, and no application-managed seed state.
- Gate C — Project ingestion: bounded HTTP/HTTPS download, explicit author selection, existing ingest reuse, cleanup, redaction, and deterministic exits pass.
- Gate D — Scenario extensions: deterministic `bulk_create_enroll_users` and `simulate_progress` pass integration and performance checks and the separate Stagehand path is retired.
- Gate D2 — Course simulation (Phase 4B): the replacement Phase 4 scenario produces realistic practice/part retries, scored assessment histories, and partial progress through shared learner operations, with fast defaults and optional wall-clock pacing. Verify isolated companion boot, invocation-wide interruption, downstream-load limits, compact waiting state, determinism, and legacy compatibility; backdated history remains deferred.
- Gate E — Deployment profile: `review_demo` consumes Phase 4B, is representative and retry-safe for complete and interrupted learner runs, the post-migration Job contract is validated, and Playwright remains independent.
- Gate F — Masquerade security: a masqueraded session is capability-equivalent to the target's direct session outside the two explicit exceptions, all general admin access is absent or denied, actor identity is usable only for audit, stop, and route-local mailbox authorization, and signed-session lifecycle, LTI clearing, and safe stop behavior pass adversarial tests.
- Gate G — UI and mailbox: required authenticated shells pass accessibility coverage and the runtime-enabled preview mailbox admits a current system administrator or the valid original admin actor during masquerade, without granting that session access to any other admin surface.
- Gate H — Release readiness: all FR/AC evidence, required reviews, formatting/tests, preview build, deployment validation, documentation, manual QA, and scope-exclusion checks pass.
