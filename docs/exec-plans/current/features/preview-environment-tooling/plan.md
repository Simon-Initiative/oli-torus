# Preview Environment Seeding and User Masquerade - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/features/preview-environment-tooling/prd.md`
- FDD: `docs/exec-plans/current/features/preview-environment-tooling/fdd.md`
- Requirements: `docs/exec-plans/current/features/preview-environment-tooling/requirements.yml`
- Course simulation design: `docs/exec-plans/current/features/preview-environment-tooling/design/course-progress-simulation.md`

## Scope

Deliver a production-shaped `MIX_ENV=preview` release with three coordinated capabilities: a synchronous `bin/seed` interface for scenario execution and project ingestion, system-administrator user masquerade for manual QA, and non-delivering preview email with a protected mailbox. Extend `Oli.Scenarios` with deterministic bulk-user and learner-progress operations, provide the themed bundled `oli_torus_getting_started_course` scenario, and run that scenario once after the preview application server completes baseline setup and becomes ready.

The implementation must preserve the non-production scenario-seeding boundary, the compile-time preview boundary for release seeding, deny-by-default runtime activation for web QA features, existing publication and authorization boundaries, existing Playwright-owned scenario setup, and the ordinary production release default. It must not add a production seeding entry point, seed UI or general HTTP API, Oban seed work, seed-run persistence, YAML snapshots, broad external-integration suppression, or a claim that unsanitized production database clones are safe.

## Clarifications & Default Assumptions

- Scenario seeding is supported in `dev`, `test`, and `ci_e2e` through existing local or token-protected Playwright interfaces and in `preview` through the privileged release CLI; `prod` exposes no supported seeding entry point. `MIX_ENV=test` compiles `seeding/lib` solely for automated verification, while `MIX_ENV=preview` is the deployable preview capability boundary. Explicit `bin/seed` invocation needs no runtime feature flag. `PREVIEW_QA_TOOLS_ENABLED` activates only masquerade and mailbox access when its value equals `true` case-insensitively; whitespace-padded and all other values keep those web features disabled.
- While masquerade is active, normal application authorization has exactly the target user's capabilities. No general system-administrator route, LiveView, API, navigation, data access, or mutation may authorize from the actor identity. The only actor-authorized exceptions are stopping masquerade and accessing the preview mailbox at `/dev/mailbox`.
- `config/preview.exs` is standalone and intentionally duplicates only applicable production-shaped settings. It imports neither `prod.exs` nor `dev.exs`.
- Preview email always uses `Swoosh.Adapters.Local`, independently of runtime activation. Other outbound integrations remain unchanged and require fresh or explicitly sanitized data plus non-production credentials.
- Shell or IEx access is the authorization and audit boundary for seeding. The CLI exposes the complete existing scenario DSL and is not an input sandbox.
- CLI scenario execution adds an explicit-ownership mode without changing the defaults used by existing tests and Playwright. Author and institution must be established in YAML before an ownership-dependent directive executes.
- Scenario and ingest operations retain their existing transaction boundaries. Once scenario execution begins, a failure may leave partial mutations and must say so without claiming rollback.
- Deployment manifests may be owned outside this repository. If implementation confirms that boundary, the Torus change must define and test the command contract and provide the exact manifest change for the owning deployment repository; the phase gate requires evidence that the owning deployment path was updated before rollout.
- No Jira write is part of this plan. If delivery tracking requires Jira changes, draft the exact proposed changes and obtain explicit user approval before using the `jira` CLI.
- Phase 4B replaces Phase 4's `simulate_progress` implementation and input/result contract before Phase 5 consumes it, retaining the directive name but removing top-level `pct_correct` and `assessment_attempts` without a compatibility mode. Migrate all existing simulator callers, tests, and examples; preserve unrelated directives and the existing bulk-user hook/example. The replacement targets learners without existing section progress and supports fast execution by default or optional real-time pacing sampled independently per learner from profile timing distributions, without a target duration window. Operators can stop the separate CLI process and preserve all committed learner progress. Backdated history and resume/reconciliation remain out of scope.
- The deployment `oli_torus_getting_started_course` scenario is a one-shot initializer for a fresh or deliberately reset preview database. Stable scenario references improve predictability within that run but are not a cross-run idempotency or completion marker. The Kubernetes Job uses `backoffLimit: 0`; after a partial failure, an operator inspects the bounded result and recreates or resets the preview environment before rerunning.

## Phase 1: Establish the Preview Build and Runtime Safety Boundary

- Goal: Make preview a production-shaped release environment whose seeding and web QA capabilities are compile-time isolated, whose web QA features are runtime-disabled by default, and which is incapable of external email delivery.
- Requirements: FR-001, FR-010; AC-001, AC-002, AC-003, AC-004, AC-025.
- Tasks:
  - [x] Audit every `Mix.env()` branch and dependency `only:` selector that affects release construction or behavior, including `mix.exs`, `config/config.exs`, `lib/oli_web/endpoint.ex`, Gleam compiler paths, permanent startup, static compression, and release-only dependencies; record which branches must treat `:preview` as production-like.
  - [x] Add standalone `config/preview.exs` with the applicable production-shaped endpoint, logging, Playwright, and release settings, an immutable preview build marker, and `Oli.Mailer` configured with `Swoosh.Adapters.Local`.
  - [x] Add `Oli.PreviewQATools.Config` as the effective-enablement boundary for web QA features, combining the compile-time preview marker with strict runtime parsing of `PREVIEW_QA_TOOLS_ENABLED`; keep the low-level seeding CLI independent of this runtime flag.
  - [x] Wire application-server startup to emit one bounded instructional warning for a preview build whose web QA runtime activation is disabled and one bounded enabled signal when active; emit neither message for other Mix environments or the dedicated seeding process.
  - [x] Parameterize the Docker build and all release-stage paths with `ARG MIX_ENV=prod`; propagate the selected environment consistently through dependency resolution, asset/release compilation, and final-stage copies.
  - [x] Update both jobs in `.github/workflows/build-preview-image.yml` to pass `MIX_ENV=preview`, while leaving production image callers on the safe default.
  - [x] Update `guides/process/building.md` with the purposes, scenario-seeding boundaries, and workflows for `dev`, `test`, `ci_e2e`, `preview`, and `prod`, standalone preview configuration ownership, compile-time versus runtime configuration, activation syntax, local-email containment, and the unsupported production-clone boundary.
- Testing Tasks:
  - [x] Add unit tests for the full environment/flag truth table, including casing variants and missing, blank, whitespace-padded, false, malformed, hostname, profile, and unrelated-flag inputs.
  - [x] Capture logs to prove the preview-disabled warning is emitted once and other environments do not emit it; verify the seeding role does not invoke web-tools status logging.
  - [x] Add configuration assertions that preview uses `Swoosh.Adapters.Local` whether the runtime flag is enabled or disabled.
  - [x] Add static environment-policy, workflow, and Docker assertions for trusted seeding in `dev`, `test`, `ci_e2e`, and `preview`; explicit production exclusion; the `prod` Docker default; both preview build arguments; and consistent environment-specific release paths.
  - [x] Compile or build the preview release through the existing preview-image path and retain existing production packaging as the production-environment gate.
  - Command(s): `mix test <targeted PreviewQATools configuration and build-policy tests>`; `MIX_ENV=preview mix compile`; `mix format`; preview-image workflow build.
- Definition of Done:
  - Preview compiles with production-shaped settings, flag-free release seeding, and local-only mail; production remains the Docker default, web QA runtime activation is deny-by-default, startup signals are bounded, and the environment contract is documented.
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
  - [x] Add the environment-neutral `Oli.Seeding.CLI` dispatcher, a development-only `mix seed` task, and the preview `rel/overlays/bin/seed` wrapper following the existing `rel/overlays/bin/migrate` pattern; exclude seeding code and the wrapper from production builds, and require no runtime feature flag for explicit CLI invocation.
  - [x] Implement strict argument parsing for `scenarios list` and `scenarios run --name <id>|--file <path>`, rejecting missing values, unknown options, extra arguments, and non-exclusive sources with bounded usage output and deterministic nonzero status.
  - [x] Define an application-owned bundled-scenario registry and immutable release asset location with stable identifier, description, and version or digest metadata; listing must read metadata without parsing or executing scenario bodies.
  - [x] Add an `Oli.Scenarios` execution adapter that preserves `use`, assertions, hooks, and the complete DSL while enabling explicit-ownership validation only for release execution.
  - [x] Support ownership through created scenario references, restricted unique lookup, and explicit configured defaults such as `default_admin`; reject missing, late, ambiguous, inactive, or wrong-type author/institution selection before the first dependent mutation.
  - [x] Emit bounded structured operation, source, identifier/digest, duration, aggregate-count, result-code, and partial-mutation fields without YAML bodies, credentials, responses, or secrets.
  - [x] Keep the dispatcher callable from IEx and avoid any web route, application role check, Oban worker, queue, run record, YAML snapshot, retry manager, or deployed-safe directive allowlist.
- Testing Tasks:
  - [x] Test scenario listing metadata and prove list does not parse or execute bundled YAML.
  - [x] Test the argument matrix, deterministic exits, bounded output, operation failures before mutation, and partial-mutation reporting after execution begins.
  - [x] Run bundled and temporary local YAML through the dispatcher, including `use` composition, assertions, and hooks.
  - [x] Test each accepted ownership mechanism and all ordering, ambiguity, activity-state, and type failures; prove legacy scenario defaults remain unchanged outside release mode.
  - [x] Add negative structural checks for seed HTTP routes, application authorization, Oban seed modules/queues, persistence schemas, and extra DSL allowlists.
  - Command(s): `mix test <release dispatcher, bundled registry, and scenario ownership tests>`; `mix format`.
- Definition of Done:
  - `mix seed` in development and `bin/seed` in a preview release execute through the same synchronous dispatcher without a runtime feature flag, expose the full scenario engine, enforce YAML-defined ownership, redact sensitive input, and return reliable status without new application-managed state; production compiles neither entry point.
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
  - The preview CLI ingests a reachable archive through `Oli.Interop.Ingest`, bounds all local resource use described in the FDD, cleans up reliably, and reveals no sensitive URL or archive data.
- Gate:
  - AC-010 and AC-011 pass with success and forced-failure cleanup evidence.
- Dependencies:
  - Phase 1 and the Phase 2 dispatcher/result contract.
- Parallelizable Work:
  - The downloader and its controlled-server tests can proceed alongside Phase 2 scenario ownership work once the common CLI result contract is fixed.

## Phase 4: Move Bulk User Enrollment into Oli.Scenarios and Retire Stagehand

- Goal: Establish deterministic bulk user enrollment as a reusable scenario directive and remove the separate Stagehand execution path before Phase 4B replaces progress simulation.
- Requirements: FR-004; AC-012, AC-014.
- Tasks:
  - [x] Define and document the `bulk_create_enroll_users` schema, validation, stable-reference rules, result shape, and failure semantics while preserving the existing `Oli.Scenarios.Hooks.create_bulk_users/1` hook and example.
  - [x] Extract bulk creation and enrollment into the focused `Oli.Scenarios.BulkCreateEnrollUsers` service rather than expanding `Oli.Accounts`.
  - [x] Implement collision-safe synthetic instructor/learner identities, deterministic scenario references, and realistic generated names.
  - [x] Register parser, validator, directive type, handler, and documentation support using the established `Oli.Scenarios` extension points.
  - [x] Move progress behavior behind the scenario boundary, then retire the standalone deployed Stagehand API after Phase 4B supplies and verifies the final simulator contract.
- Testing Tasks:
  - [x] Add parser/validator and integration coverage for valid and invalid attributes, role/enrollment creation, stable references, identity collisions, generated identities, and preservation of the existing bulk-user hook.
  - [x] Run affected Stagehand and scenario suites before removal, then add a repository check proving no separate deployed Stagehand call path remains.
  - Command(s): `mix test <bulk_create_enroll_users and migrated Stagehand tests>`; `mix test test/scenarios`; `mix format`.
- Definition of Done:
  - Bulk creation and enrollment are a normal scenario operation with deterministic references, the original hook remains available, progress ownership is ready for the Phase 4B replacement, and Stagehand is no longer an independent deployed interface.
- Gate:
  - AC-012 and AC-014 pass, existing scenario behavior remains green, and Phase 4B owns all final `simulate_progress` acceptance and performance evidence.
- Dependencies:
  - Phase 2 establishes release execution and explicit ownership; directive service extraction itself may start after the relevant scenario extension points are confirmed.
- Parallelizable Work:
  - Bulk-user implementation and Phase 4B design can proceed in parallel once the scenario registration and stable-reference conventions are agreed.

## Phase 4B: Implement Profile-Driven Course Progress Simulation

- Goal: Replace Phase 4's `simulate_progress` contract with one small course-level simulator that produces authentic, varied learner progress for development and preview QA.
- Requirements: FR-004, FR-005; AC-012, AC-013, AC-016, AC-027, AC-028, AC-029, AC-030, AC-031, AC-032, AC-033, AC-034. Detailed behavior is specified in `docs/exec-plans/current/features/preview-environment-tooling/design/course-progress-simulation.md`; the module/runtime shape is captured in `docs/exec-plans/current/features/preview-environment-tooling/design/progress-simulation-architecture.md`.
- Tasks:
  - [x] Reconcile `requirements.yml`, PRD, FDD, detailed design, architecture, and this plan with the simplified replacement contract. Retain unrelated scenario directives and `bulk_create_enroll_users`; reject the retired `pct_correct` and `assessment_attempts` inputs.
  - [x] Retain the dedicated `Oli.Seeding.Runtime` used by development `mix seed` and preview `bin/seed`. Start required persistence, cache, evaluation, event, and job-production services without the endpoint, normal consumers/plugins, upload pipeline, or inventory recovery.
  - [x] Extract and reuse `LearnerActions` for authentic visit, evaluate, save, hint, reset, and finalize operations. Run those calls directly in the learner worker and rely on normal Repo/domain timeouts and database transaction boundaries.
  - [x] Support UI-valid seeded responses for multiple choice, ordering, check all that apply, short answer, and both multi-input submission modes using current transformed models and real part identities.
  - [x] Implement real practice resets/retries, hint requests after incorrect practice attempts, and repeated scored assessment save/finalize lifecycles. Increase correctness probability by attempt number while leaving scores and retained grades to the evaluator and grading policy.
  - [x] Provide four immutable profiles with only course reach, activity participation, initial correctness, practice attempt count, assessment attempt count, and improvement per attempt. Remove profile versions and arbitrary overrides.
  - [x] Support either one profile or complete count-based cohorts. Validate learner enrollment, exact cohort cardinality, profile names, and one fixed 100-learner cap before mutation.
  - [x] Keep fast mode as the default and paced mode as an explicit option. Keep fixed profile distributions for start/page/answer/retry/break/study-session timing, and apply paced waits directly in learner workers without a central scheduler or historical timestamp backfill.
  - [x] Use one unordered `Task.async_stream/3` with its normal concurrency in fast mode and one worker per admitted learner in paced mode so realistic waits overlap. Add a small deterministic fast-mode delay at modeled wait points to smooth bursts without reintroducing action budgets, action-rate throttling, per-action tasks, cumulative active-work timeouts, course-size envelopes, ETS sharing, retained-wait benchmarks, or rich progress telemetry.
  - [x] Derive one deterministic DataShop UUID from seed, learner identity, and section and reuse it for the complete learner simulation. Keep study-session boundaries as pacing behavior only; retain independent transient IDs for lower-level directives.
  - [x] Partition selected learners using existing section history. Skip and report existing-history learners, simulate fresh learners, and add no resume, reconciliation, cleanup, run persistence, or backdated history.
  - [x] Keep result output compact: selected, processed, skipped, failed, course outcome, lifecycle-operation, profile, and bounded unsupported-content counts. Remove scheduler, rate, action-budget, fingerprint, and cancellation reporting.
  - [x] Replace the canonical 40-learner scenario in place with two ungraded pages, one graded assessment, all supported native activity types, and simple count-based cohorts. Keep a paced variant for manual real-time QA.
- Testing Tasks:
  - [x] Verify parser and JSON-schema parity for single profiles, count cohorts, fast/paced mode, missing/invalid selections, exact cardinality, removed inputs, and removed tuning/version/override options.
  - [x] Verify fixed profiles, deterministic policy decisions, triangular timing bounds, attempt-number improvement, native response validity, and deterministic learner/section UUIDs.
  - [x] Run scenario integration coverage for all five native types, both multi-input modes, practice resets, hints, repeated assessments, real evaluator scores, grading-policy results, and one DataShop ID per learner journey.
  - [x] Verify learners with existing section history are skipped and reported while fresh learners can continue.
  - [x] Verify the simple pacing helper and keep long-running real-time validation out of CI.
  - [x] Verify the dedicated runtime composition, development CLI dispatch, compact summary, and absence of simulator Oban polling.
  - [x] Run the canonical scenario through development `mix seed` alongside a running server and inspect learner progress and downstream job consumption.
  - Command(s): `mix compile`; focused progress/parser/runtime/CLI tests; `mix test test/oli/scenarios/progress_simulation_scenario_test.exs --timeout 120000`; affected lower-level directive suites; `mix seed scenarios run --file test/oli/scenarios/data/progress_simulation.scenario.yaml`; `mix format`; `git diff --check`.
- Definition of Done:
  - A supported scenario produces varied course progress through authentic delivery lifecycles in fast or realistically paced mode with fixed profiles. Existing-history learners are skipped, process termination ends remaining work, and the implementation contains no limiter, per-action runner, central scheduler, resume machinery, or speculative benchmark/telemetry subsystem.
- Gate:
  - AC-013 and AC-027 through AC-034 have passing automated evidence and the development entry-point check is recorded. Preview `bin/seed` and longer paced-run manual checks are explicitly deferred to Phase 9. No legacy simulator branch remains.
- Dependencies:
  - Phase 4's scenario services and directive contract; Phase 2's CLI and explicit ownership; Phase 1's preview release for release-level verification.
- Parallelizable Work:
  - Profile/policy/response unit verification may proceed independently from environment-level development and preview CLI smoke testing.

## Phase 5: Deliver the OLI Torus Getting Started Course and Deployment Job Contract

- Goal: Deliver a cohesive “Getting Started with OLI Torus” demo course and automatically seed it once, after baseline release setup and application readiness, in Argo CD pull-request preview environments.
- Requirements: FR-005, FR-006; AC-015, AC-016, AC-017, AC-018.
- Tasks:
  - [x] Create `docs/exec-plans/current/features/preview-environment-tooling/design/oli-torus-getting-started-course.md` with the complete course structure and page-by-page content for “Getting Started with OLI Torus.” Define the learning objectives, several unscored practice pages, one scored assessment, explanatory authoring and publishing content, and each page's activities, hints, correct feedback, and incorrect feedback. Map every objective and activity to its page so the YAML implementation is mechanical and reviewable.
  - [x] Implement and register `priv/preview_qa_tools/scenarios/oli_torus_getting_started_course.yaml`, using `test/oli/scenarios/data/progress_simulation.scenario.yaml` as the structural example. Create the designed project and content, publish it, create a section, bulk-create and enroll a modest cohort, and finish with fast-mode `simulate_progress` using fixed count-based learner profiles. Package updated manifest metadata and digest with no embedded credentials.
  - [x] Add Torus-owned Kubernetes examples under `docs/manifests/preview-seeding/` for a one-shot scenario Job and its Kustomize/Argo CD integration. The example must use the same preview release image, runtime ConfigMap/Secret and service account as the app, pass `oli_torus_getting_started_course` as a discrete `bin/seed scenarios run --name oli_torus_getting_started_course` argument, set `restartPolicy: Never` and `backoffLimit: 0`, declare resources, retain bounded Job logs/status, and explain fresh/reset-data recovery after failure.
  - [x] Update `oli-torus-gitops` so `apps/oli-torus/overlays/preview` includes the seed Job and `PREVIEW_QA_SEED_SCENARIO=oli_torus_getting_started_course`, following the Torus manifest examples. Order the retained Job in a later Argo CD sync wave than the application Deployment so the Deployment's `release-setup` init container has completed baseline create/migrate/seed and the application server is Ready before `bin/seed` begins. (Prepared on the requested separate, uncommitted `oli-torus-gitops` branch.)
  - [x] Update the `oli-torus-gitops` `oli-torus-pr-previews` ApplicationSet contract so each new PR preview namespace runs that Job exactly once, a later PR image update or Argo CD resync does not replace or rerun the completed Job, and closing the PR prunes the Job with the namespace. Keep this lifecycle entirely in GitOps; add no Torus startup coordinator, readiness endpoint, Job API client, seed-run persistence, automatic retry, or learner-progress reconciliation. (Prepared on the requested separate, uncommitted `oli-torus-gitops` branch.)
  - [x] Update Torus and `oli-torus-gitops` operator documentation with the development command, preview-release command, `PREVIEW_QA_SEED_SCENARIO` behavior, Argo CD ordering/lifecycle, Job observation, and reset/recovery procedure. Preserve Playwright's independent per-spec scenario setup and document that paced simulation remains an operator-invoked workflow rather than the automated preview initializer.
- Testing Tasks:
  - [x] Validate the bundled YAML and execute it in scenario integration coverage. Assert the title and curriculum hierarchy, learning-objective associations, rich content, unscored/scored page purposes, activity hints and feedback, publication/section/enrollment state, supported activity responses, simulated attempts, progress, and gradebook results.
  - [x] Run `mix seed scenarios run --name oli_torus_getting_started_course` against a fresh development database with the Phoenix server running and verify the course, learners, progress, and scores through the application.
  - [x] Build a preview release and run `bin/seed scenarios run --name oli_torus_getting_started_course` alongside its running server; verify the same resulting state and bounded success output without starting a second endpoint or consumer stack.
  - [x] Render the Torus example manifests and the changed `oli-torus-gitops` preview overlay/ApplicationSet. Assert the app image/env/service-account reuse, direct argv, `PREVIEW_QA_SEED_SCENARIO`, readiness ordering, fixed Job identity, resource settings, `restartPolicy: Never`, `backoffLimit: 0`, and namespace cleanup ownership.
  - [x] Exercise a disposable Argo CD PR preview: verify baseline release setup completes, the server becomes Ready, the seed Job then succeeds once, and the demo course is visible. Update the PR image and resync to prove the completed Job does not rerun; close the PR and confirm namespace pruning removes it.
  - [x] Run the existing Playwright scenario-fixture tests and prove they reference neither `oli_torus_getting_started_course` nor the deployment seed Job. (PR Playwright run `35372591197`: 4 passed; independence contract: 3 passed. Evidence is recorded in the Phase 5 execution record.)
  - Command(s): `mix test <getting-started scenario and bundled-registry tests>`; `mix seed scenarios run --name oli_torus_getting_started_course`; `MIX_ENV=preview mix release`; preview `bin/seed scenarios run --name oli_torus_getting_started_course`; `mix format`; `kubectl kustomize <Torus example path>`; in `oli-torus-gitops`, `kubectl kustomize apps/oli-torus/overlays/preview`, `kubectl kustomize argocd`, and repository validation scripts; existing Playwright fixture test command.
- Definition of Done:
  - The themed bundled scenario runs successfully through development and preview-release entry points, and an Argo CD pull-request preview runs its retained seed Job exactly once after baseline setup and server readiness. The resulting demo instance contains the course, cohort, progress, and grades needed for QA, while subsequent syncs do not duplicate them and Playwright remains independently self-seeding.
- Gate:
  - AC-015 through AC-018 pass with automated scenario/render coverage and one hybrid PR-preview lifecycle check proving ready-before-seed ordering, dev/release parity, exactly-once-per-namespace execution, later-sync stability, and cleanup on PR close.
- Dependencies:
  - Phases 1, 2, and 4B.
- Parallelizable Work:
  - The course blueprint precedes YAML authoring. Torus manifest examples and `oli-torus-gitops` implementation can proceed alongside scenario authoring once the command, image, environment, and readiness-ordering contract is fixed.

## Phase 6: Add Protected Mailbox Access

- Goal: Make captured preview email available to enabled current system administrators before masquerade implementation begins.
- Requirements: FR-010; AC-025, AC-026 (current-admin access and compile/runtime/authentication boundaries; masquerade integration completes in Phase 7).
- Tasks:
  - [ ] Compile `/dev/mailbox` only for preview, consolidate the existing development/test mailbox declaration under one policy, and place `Plug.Swoosh.MailboxPreview` behind `:browser`, effective runtime enablement, and a dedicated mailbox authorization plug that requires a current system administrator.
  - [ ] Keep authorization route-local and leave `current_user` unchanged. Reject unvalidated actor/session claims; Phase 7 adds the original-admin exception using its validated masquerade lifecycle.
  - [ ] Return a non-disclosing response for disabled, unauthenticated, non-admin, expired, or invalid-session mailbox requests and prevent message contents and metadata from entering application telemetry.
  - [ ] Document mailbox access and runtime activation so administrators can inspect captured email before masquerade is available.
- Testing Tasks:
  - [ ] Test mailbox compile/runtime/auth truth tables for preview and non-preview builds, including anonymous, author, ordinary user, stale-admin, current system-admin, expired/invalid sessions, and forged actor/session claims.
  - [ ] Send representative email in preview with activation both on and off, prove it remains local, and verify only an enabled current system administrator can inspect it.
  - [ ] Verify the mailbox plug leaves `current_user` unchanged and denied requests disclose no message contents or metadata in responses or telemetry.
  - Command(s): `mix test <mailbox route, authorization, and preview email containment tests>`; `mix format`.
- Definition of Done:
  - Protected mailbox access works independently of masquerade, preview mail cannot leave through `Oli.Mailer`, and only an enabled current system administrator can inspect captured messages.
- Gate:
  - AC-025 and the non-masquerade portion of AC-026 pass; security review approves the compile/runtime/authentication matrix before Phase 7 starts. Full AC-026 acceptance requires the Phase 7 masquerade integration tests.
- Dependencies:
  - Phase 1 effective-enablement, compile boundary, and local email configuration; no masquerade dependency.
- Parallelizable Work:
  - Mailbox route/authorization work and email-containment verification can proceed alongside Phases 2 through 5 after Phase 1; this phase must complete before Phase 7 begins.

## Phase 7: Implement Secure Masquerade Identity and Session Lifecycle

- Goal: Let an enabled current system administrator act as an active delivery user while preserving actor accountability, target-only authorization, and fail-closed lifecycle behavior.
- Requirements: FR-007, FR-008, FR-010; AC-019, AC-020, AC-021, AC-022, AC-026.
- Tasks:
  - [ ] Add preview-compiled `Oli.PreviewQATools.Masquerade` start, restore, stop, expiry, and invalidation services with effective-enablement checks and system-administrator authorization at every actor-sensitive boundary.
  - [ ] Store only bounded actor ID, target ID, issued/expiry timestamps, and random session reference in the existing tamper-protected signed session; renew the session on start and make no application-wide encryption or active-session-table change.
  - [ ] Restrict targets to active delivery users, reject self/chained masquerade, revalidate actor, target, flag, expiry, and signed state on every restoration, and clear invalid state safely.
  - [ ] Install only the target as `current_user` across plugs, LiveView mounts, sockets, controllers, APIs, policies, context calls, and rendered navigation; never retain or expose an actor-derived admin role, permission set, current-author identity, or privileged assign while masquerade is active.
  - [ ] Keep actor identity in a separately named, private session/audit representation that no general authorization function accepts. Expose it only to audit emission and two dedicated authorization boundaries: stopping masquerade and accessing the preview mailbox at `/dev/mailbox`.
  - [ ] Extend the Phase 6 mailbox authorization plug to accept the original system-administrator actor only after the masquerade service validates the active session, current actor privileges, target, expiry, and runtime enablement. Keep this exception route-local, retain the target as `current_user`, and expose no actor privileges to downstream general authorization helpers.
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
  - [ ] Extend the Phase 6 mailbox matrix to cover a valid admin masquerading as a non-admin target, revoked/stale actors, expired or invalid sessions, non-admin-originated and forged masquerade requests, and runtime disablement. Prove the valid actor can inspect captured mail while the target remains `current_user` and adjacent system-admin routes remain denied.
  - [ ] Capture intentional audit/log output and prove session state contains only the bounded signed identifiers and timestamps.
  - Command(s): `mix test <masquerade service, auth/session, admin user detail, audit, mailbox integration, and LTI boundary tests>`; `mix format`.
- Definition of Done:
  - Masquerade is preview-compiled, runtime-gated, system-admin initiated, non-chainable, expiring, auditable, safely stoppable, and capability-equivalent to signing in directly as the target user, except for the narrowly isolated actor-authorized stop and preview-mailbox capabilities.
- Gate:
  - AC-019 through AC-022 and full AC-026 pass with direct-versus-masqueraded target capability parity, explicit denial of every sampled general admin surface and mutation, tamper/lifecycle evidence, and security-review confirmation that actor privilege is reachable only at stop and `/dev/mailbox`.
- Dependencies:
  - Phase 1 effective-enablement and compile boundary; Phase 6 protected mailbox gate must pass before masquerade implementation begins.
- Parallelizable Work:
  - Audit event design, signed-session lifecycle, and system-admin surface integration can proceed concurrently after the session payload and service interface are agreed.

## Phase 8: Add Persistent Masquerade UI

- Goal: Make active masquerade unmistakable and immediately reversible across authenticated shells.
- Requirements: FR-009; AC-023, AC-024.
- Tasks:
  - [ ] Add `OliWeb.Components.MasqueradeBanner` with the target's identity, explicit “acting as” wording, high-contrast magenta styling, non-color warning cues, a keyboard-operable CSRF-protected stop control, and screen-reader labels/status semantics.
  - [ ] Integrate the banner once per authenticated root across `default`, `workspace`, `delivery`, `delivery_student_dashboard`, `delivery_dashboard`, authenticated LiveView, and authenticated `chromeless` surfaces without changing unauthenticated layout behavior.
  - [ ] Keep `delivery_from_payment` and `lti` layouts banner-free, relying on the Phase 7 LTI identity-boundary clearing/rejection behavior.
- Testing Tasks:
  - [ ] Add a layout matrix test proving exactly the required authenticated surfaces render one banner and that `delivery_from_payment`, `lti`, unauthenticated, disabled, and ordinary sessions do not.
  - [ ] Test visible target identification, non-color wording/iconography, focus order, keyboard activation, accessible name/status semantics, color contrast, responsive placement, and stop behavior.
  - Command(s): `mix test <masquerade component/layout tests>`; `mix format`; targeted manual keyboard and screen-reader check.
- Definition of Done:
  - Every required authenticated surface communicates masquerade accessibly and offers immediate stop; excluded identity/payment layouts remain unchanged.
- Gate:
  - AC-023 and AC-024 pass; UI/accessibility and security reviews approve the complete layout matrix.
- Dependencies:
  - Phases 1 and 7; Phase 7 depends on completed Phase 6 protected mailbox access.
- Parallelizable Work:
  - Banner component work and layout integration can proceed in parallel after the Phase 7 session and stop interfaces are agreed.

## Phase 9: Integrated Verification, Review, and Rollout Readiness

- Goal: Prove end-to-end behavior, requirement coverage, scope exclusions, operational safety, and maintainability before preview rollout.
- Requirements: FR-001 through FR-010; AC-001 through AC-034.
- Tasks:
  - [ ] Reconcile implementation evidence against every requirement and acceptance criterion in `requirements.yml`, updating proof references without weakening the approved PRD/FDD contract.
  - [ ] Run focused security, performance, Elixir, UI/accessibility, and requirements reviews under `.review/`; include TypeScript or Gleam review only if final changed files require those lenses.
  - [ ] Inspect the final diff for sensitive logging, unbounded output/work, unsafe URL handling, authorization bypass, privilege inheritance, N+1 queries, compile/runtime boundary drift, and undocumented operational assumptions.
  - [ ] Confirm excluded scope remains absent: seed UI/API, Oban seed scheduling, seed history/YAML persistence, a seed startup-status endpoint, broad external-integration suppression, and production-clone safety claims.
  - [ ] Finalize operator documentation for CLI syntax, synthetic-data responsibility, partial-mutation behavior, deployment scenario selection, one-shot Job observation and reset/recovery ownership, local mailbox access, masquerade lifecycle, and safe disablement.
  - [ ] Execute the manual QA matrix from a preview-built image and fresh preview data: list scenarios, run bundled and custom YAML, ingest a controlled archive, run the deployment scenario once, inspect captured mail, masquerade as instructor and learner across all required shells, stop safely, and confirm disabled/non-preview rejection.
- Testing Tasks:
  - [ ] Run all targeted suites from prior phases, then the broader affected backend and scenario suites.
  - [ ] Run formatting and compile gates, the full preview-image release build, deployment manifest validation, and existing production packaging evidence.
  - [ ] Run the staged canonical scenario through preview `bin/seed`, confirming the companion starts no endpoint/consumer/recovery process and the server sees committed data.
  - [ ] Manually smoke-test a longer paced run alongside the server, confirm randomized delays and journeys, terminate the foreground command, and verify the simulation VM/workers stop while the server and committed progress remain.
  - [ ] Validate the work-item traceability and plan structure with the Harness scripts.
  - Command(s): `mix test <all affected targeted test files>`; `mix test test/oli/scenarios test/scenarios`; `MIX_ENV=preview mix compile`; preview `bin/seed` with a staged scenario; longer paced seed run alongside the server; `mix format`; `git diff --check`; preview-image workflow build; existing production package/release workflow; Harness requirements and plan validators.
- Definition of Done:
  - All AC-001 through AC-034 have passing automated or hybrid evidence, all required reviews are resolved, manual preview QA passes, documentation matches the shipped interfaces, and excluded application surface remains absent.
- Gate:
  - Final release-readiness review accepts the requirements evidence, preview build, deployment contract, security/performance/accessibility results, and operational rollback of disabling runtime QA tools; no unresolved implementation marker remains.
- Dependencies:
  - Phases 1 through 8, including Phase 4B.
- Parallelizable Work:
  - Review lenses and documentation verification may run concurrently after the implementation diff stabilizes; end-to-end manual QA begins only after all phase gates pass.

## Parallelization Notes

- Phase 1 is the critical-path foundation because all callable capabilities depend on its compile-time and runtime boundary.
- After Phase 1, Phase 2 CLI/scenario ownership and Phase 6 protected mailbox access are independent workstreams. Phase 7 masquerade lifecycle starts only after the Phase 6 mailbox gate passes. Phase 3 can begin once Phase 2 fixes the common CLI result interface.
- Phase 4 bulk-user work can overlap Phases 2 and 3. Phase 4B owns the replacement course simulation consumed by Phase 5. The Phase 5 course blueprint must precede YAML authoring, while Torus manifest examples and `oli-torus-gitops` work may proceed concurrently after the release command and readiness-ordering contract are fixed.
- Phase 8 UI work can overlap Phases 2 through 5 once the Phase 7 masquerade state and stop contracts are stable; the Phase 6 mailbox gate remains a prerequisite for Phase 7.
- Assign one owner to changes in shared scenario parser/validator/runtime files and one owner to shared router/session/layout files to avoid conflicting edits. Integrate each workstream only after its focused gate is green.
- Review and verification tasks should be performed continuously within phases; Phase 9 consolidates evidence rather than postponing security, performance, accessibility, or test work.

## Phase Gate Summary

- Gate A — Environment boundary: trusted scenario seeding is available in `dev`, `test`, `ci_e2e`, and `preview`; `MIX_ENV=preview` builds production-shaped with flag-free release seeding; `MIX_ENV=test` compiles seeding sources solely for verification; web QA runtime activation is deny-by-default; production exposes no seeding entry point or preview release tooling; and preview email is always local.
- Gate B — Scenario CLI: bundled listing and synchronous bundled/custom execution pass with strict usage, full DSL compatibility, explicit ownership, bounded output, and no application-managed seed state.
- Gate C — Project ingestion: bounded HTTP/HTTPS download, explicit author selection, existing ingest reuse, cleanup, redaction, and deterministic exits pass.
- Gate D — Scenario foundation: deterministic `bulk_create_enroll_users` passes integration checks, the existing bulk-user hook remains available, and the separate Stagehand path is retired; the final simulator is gated only by Phase 4B.
- Gate D2 — Course simulation (Phase 4B): AC-027 through AC-034 verify that the replacement simulator and migrated Phase 4 scenario produce realistic practice/part retries, scored assessment histories, partial progress, and one deterministic DataShop ID per learner/section journey through shared learner operations, with fast defaults and optional wall-clock pacing. Verify isolated companion boot, foreground-process termination, normal fast task concurrency with small action delays, concurrent paced learner journeys, the 100-learner cap, compact aggregate output, deterministic response variation, complete input/result migration, and removed-option rejection; no legacy simulator branch remains and backdated history stays deferred.
- Gate E — Demo scenario and deployment: the “Getting Started with OLI Torus” scenario passes dev and release execution, and each Argo CD PR preview runs the seed Job once after baseline setup and server readiness without rerunning on later syncs; Playwright remains independent.
- Gate F — Protected mailbox: preview-only routing, runtime activation, current-admin authentication, non-disclosing denials, local email containment, and telemetry privacy pass before masquerade implementation begins; Phase 7 completes the masquerade-specific portion of AC-026.
- Gate G — Masquerade security: a masqueraded session is capability-equivalent to the target's direct session outside the two explicit exceptions, all general admin access is absent or denied, actor identity is usable only for audit, stop, and route-local mailbox authorization, the valid original admin actor can inspect the Phase 6 mailbox without changing target identity or gaining adjacent admin access, and signed-session lifecycle, LTI clearing, and safe stop behavior pass adversarial tests.
- Gate H — Masquerade UI: required authenticated shells pass the banner layout and accessibility matrices, including target identification and immediate stop; excluded identity/payment layouts remain banner-free.
- Gate I — Release readiness: all FR/AC evidence, required reviews, formatting/tests, preview build, deployment validation, documentation, manual QA, and scope-exclusion checks pass.
