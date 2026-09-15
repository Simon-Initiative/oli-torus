# Preview Environment Seeding and User Masquerade - Product Requirements Document

## 1. Overview
Support QA preview instances with three coordinated capabilities: CLI-based data seeding and project ingestion, system-administrator user masquerading for manual QA, and non-delivering email with an administrator-authenticated mailbox for inspecting captured messages. The CLI lists and executes bundled scenarios, executes operator-provided YAML, and ingests Torus project archives from reachable URLs. Pull-request preview deployments use the same CLI to initialize the bundled `oli_torus_getting_started_course` scenario once after baseline setup and application readiness. There is no seed workbench, HTTP seed API, Oban seed scheduling, or persistent seed-run history.

Preview images are built as a dedicated `MIX_ENV=preview` release with standalone configuration that explicitly owns its production-shaped settings and QA safety delta. This environment is the compile-time capability boundary and makes the low-level `bin/seed` command available without another runtime flag. `PREVIEW_QA_TOOLS_ENABLED` must equal `true`, case-insensitively, to activate web-accessible masquerade and mailbox features. Shell access is the authorization boundary for seed operations; application authorization remains mandatory for masquerade.

## 2. Background & Problem Statement
Fresh preview environments lack representative projects, sections, users, enrollments, and learner progress. Torus already has a YAML scenario engine, Playwright scenario fixtures, project archive ingestion, and Stagehand prototype behavior. The previous design added an in-application seed workbench, a deployed-safe DSL policy, Oban execution, durable run records, and YAML audit storage. Research into GitLab's development tooling showed a simpler industry pattern: reviewed or operator-provided seed files are executed through privileged CLI tasks, with the ordinary application UI used to inspect the resulting data.

Torus should follow that operational boundary. Developers with deployment shell access can already execute privileged code, so an additional application authorization and job-management layer does not materially improve security. Manual QA still needs masquerade because switching among generated learner and instructor identities is otherwise cumbersome.

## 3. Goals & Non-Goals
### Goals
- Provide one release-compatible CLI for listing bundled scenarios, synchronously executing bundled or custom YAML scenarios, and ingesting projects from reachable archive URLs.
- Reuse the same CLI from a retained Kubernetes Job to initialize `oli_torus_getting_started_course` once per pull-request preview namespace after baseline setup and application readiness.
- Extend `Oli.Scenarios` with deterministic bulk-user enrollment and one profile/cohort-driven course-progress directive, replacing the Phase 4 simulator contract and retiring Stagehand as a separate execution path.
- Preserve Playwright's existing per-spec scenario setup.
- Let system administrators masquerade as existing users while preserving actor accountability and target-only authorization.
- Give preview releases non-delivering email independently of runtime activation, with captured messages visible through an authenticated mailbox only when QA tools are enabled.
- Compile release seeding and web QA capabilities only into `MIX_ENV=preview` releases; keep web-accessible capabilities disabled unless explicitly activated at runtime.

### Non-Goals
- An administrative seeding workbench, YAML editor, seed HTTP API, or startup-status endpoint.
- Oban-based seed scheduling, seed queues, seed-run persistence, execution history, stored YAML snapshots, or application-managed seed retries.
- An additional deployed-safe directive/assertion allowlist for operators who already possess shell access.
- Application-level authorization for CLI seed execution beyond the feature flag.
- Automatic rollback, environment reset, or deletion of scenario-created records.
- Replacing Playwright's test-owned scenario lifecycle.
- Removing user masquerade from the work item.
- Making unsanitized production database clones safe for preview use or adding preview-specific suppression for LTI grade passback, Stripe, Cashnet, webhooks, background jobs, analytics destinations, or other external integrations.

## 4. Users & Use Cases
- Developers and QA operators with shell access: list bundled scenarios and run a bundled or custom YAML scenario synchronously.
- Deployment automation: invoke `oli_torus_getting_started_course` through a later-wave Kubernetes Job and use process exit status to determine success.
- Developers with shell access: ingest a Torus project archive from a reachable HTTP or HTTPS URL.
- Playwright suites: continue executing colocated scenarios through their existing test-only interface.
- System administrators: masquerade as seeded instructors or learners for manual QA, then stop safely.

## 5. UX / UI Requirements
- Do not add a seed-management UI or expose seed execution through an application route.
- Add `Act as user` to the existing system-admin user detail surface only when enabled and authorized.
- Expose sent QA email through `Plug.Swoosh.MailboxPreview` at `/dev/mailbox` only when effectively enabled and authenticated as a system administrator, including when that administrator is actively masquerading as another user.
- During masquerade, show a persistent high-contrast magenta warning across the `default`, `workspace`, `delivery`, `delivery_student_dashboard`, `delivery_dashboard`, authenticated LiveView, and authenticated `chromeless` surfaces. Identify the target user and provide an immediate `Stop acting as user` action.
- Do not carry masquerade through a new LTI login/launch identity flow: clear or reject active masquerade state at that boundary. The `lti` and Cashnet-only `delivery_from_payment` layouts do not render the banner.
- The warning and stop action must be keyboard accessible, screen-reader labeled, and understandable without color.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Security: `MIX_ENV=preview` controls compile-time inclusion. Release-shell invocation is the activation and authorization boundary for `bin/seed`, while `PREVIEW_QA_TOOLS_ENABLED` independently controls runtime access to masquerade and the mailbox. Masquerade additionally requires a current system administrator at every boundary.
- Reliability: CLI commands execute synchronously, print bounded results, and return reliable process exit codes. Kubernetes owns Job resource limits and status. The deployment seed is a one-shot initializer and is not automatically retried after partial mutation.
- Input handling: custom scenarios use the full existing `Oli.Scenarios` contract. URL ingestion supports HTTP and HTTPS with bounded download time, redirects, and archive size, and always cleans temporary files.
- Performance: course progress simulation admits at most 100 learners, uses normal task-stream concurrency plus a small deterministic delay between actions in fast mode, starts one worker per admitted learner in paced mode so realistic waits overlap, and uses fixed profile attempt caps. Oban owns downstream job execution concurrency; the simulator does not poll or throttle Oban queues. Kubernetes seed Jobs declare CPU/memory limits, and there is no seed-specific global wall-clock timeout.
- Privacy: operators must use synthetic QA data. CLI logs and summaries must not print credentials, learner responses, archive contents, or complete YAML bodies.
- Accessibility: masquerade UI meets the repository's WCAG 2.1 AA expectations.
- External effects: every `MIX_ENV=preview` release must replace outbound email delivery with `Swoosh.Adapters.Local` regardless of runtime QA-tool activation. Other external integrations are outside this work item and depend on preview instances using fresh or explicitly sanitized databases and non-production runtime credentials.

## 9. Data, Interfaces & Dependencies
- Add one environment-neutral seeding dispatcher with a `mix seed` entry point in development and a `bin/seed` release-overlay entry point in preview. Both expose `scenarios list`, `scenarios run --name <bundled-id>`, `scenarios run --file <yaml-path>`, and `projects ingest --url <http(s)-url> --author <selector>` operations. Scenario `--name` and `--file` are mutually exclusive, and production builds exclude the seeding implementation.
- Bundled scenarios are immutable release assets under a documented application-owned directory. Listing returns stable identifier, description, and version/digest.
- Scenario execution calls `Oli.Scenarios` synchronously and supports its complete DSL, including composition, assertions, and hooks. The CLI does not accept inline Elixir expressions as seed definitions.
- Every CLI-executed scenario must explicitly establish its author and institution through YAML using created scenario references, restricted lookup, or explicit configured-default selectors. It must not inherit the engine's first-record or generated-default fallback.
- URL ingestion downloads an export archive to a temporary file and invokes the existing `Oli.Interop.Ingest` boundary with an explicitly selected author. It reports the created project identity and removes temporary data after any outcome.
- Keep `bulk_create_enroll_users` and replace `simulate_progress` with a course-level profile/cohort contract. The simulator requires exactly one fixed profile or complete count-based cohort assignment, supports `high_proficiency`, `steady_learner`, `persistent_learner`, and `low_engagement`, and accepts no profile versioning or arbitrary overrides.
- The simulator traverses delivered curriculum through normal learner visit, evaluation, hint, reset, save, and finalization lifecycles. It supports native multiple-choice, ordering, check-all-that-apply, short-answer, and multi-input configurations; actual evaluators and grading policies determine scores and retained grades.
- Fast execution is the default. Optional paced execution samples fixed per-profile page, answer, retry, break, and study-session distributions and sleeps against real wall-clock time without a requested completion window. The foreground process owns all learner workers, so terminating it stops the simulation immediately while already committed database work remains.
- Derive one deterministic DataShop UUID from the seed, learner identity, and section and reuse it for the learner's complete simulated journey. Study-session timing changes waits only; it does not rotate the DataShop identifier or alter lower-level directives.
- Both seeding entry points bootstrap a dedicated companion runtime that excludes the endpoint, unrelated consumers, upload pipelines, and startup recovery. The simulator uses fixed learner concurrency and does not add action budgets, rate controls, queue polling, rich telemetry, or retained scheduler state.
- The bundled `oli_torus_getting_started_course` scenario creates a cohesive “Getting Started with OLI Torus” course. It includes learning objectives, rich explanatory content about authoring and publishing, several unscored practice pages, one scored assessment, activities with hints and correct/incorrect feedback, a synthetic enrolled cohort, and simulated progress and grades. It targets a fresh or deliberately reset preview database, contains no credentials, and adds no cross-run reconciliation or resume behavior.
- Keep bounded masquerade identifiers and timestamps in the existing tamper-protected signed session and audit the lifecycle through `Oli.Auditing`; no active-session database table or application-wide session-encryption change is introduced.
- In `MIX_ENV=preview`, configure `Oli.Mailer` with `Swoosh.Adapters.Local` regardless of runtime activation. Compile `/dev/mailbox` only into preview releases and runtime-gate it under system-admin authentication. While masquerading, ordinary authorization uses only the target identity; the original administrator identity may authorize only stopping masquerade and accessing `/dev/mailbox`. Do not add preview branches to LTI grade passback, Stripe, Cashnet, or other external-integration code.

## 10. Repository & Platform Considerations
- Put release orchestration and scenario extensions under `lib/oli/`; retain web/session concerns under `lib/oli_web/`.
- Use a release task/overlay command compatible with the existing `rel/overlays/bin/migrate` pattern rather than a Mix task that is unavailable in a production release.
- Build preview releases with `MIX_ENV=preview`. `config/preview.exs` is standalone: initially copy only the applicable production-shaped settings and explicitly own the QA safety and capability configuration. It imports neither `prod.exs` nor `dev.exs`. During implementation, inspect existing compile-time environment branches and treat `:preview` as production-like where required, including permanent startup, compressed static assets, compiler paths/options, and dependency selection.
- Update `guides/process/building.md` so developers can readily discover the purposes of `test`, `prod`, and `preview`; which workflows build each environment; how compile-time configuration differs from `config/runtime.exs`; why `bin/seed` needs no runtime flag; and how `PREVIEW_QA_TOOLS_ENABLED` activates web QA capabilities in a preview release.
- Reuse `Oli.Interop.Ingest` rather than implementing archive import again.
- Preserve institution, publication, enrollment, and immutable-content boundaries by using existing contexts.
- Existing Playwright setup remains unchanged and may continue using its test-only controller and runtime defaults.
- Implementation changes require security, performance, Elixir, UI, and requirements review lenses.
- Jira remains the issue tracker; this document performs no Jira write.

## 11. Feature Flagging, Rollout & Migration
- `MIX_ENV=preview` is the compile-time capability boundary. The Docker build accepts `MIX_ENV` as a build argument with `prod` as its safe default; both jobs in `.github/workflows/build-preview-image.yml` pass `MIX_ENV=preview`, while production image workflows retain the default.
- Existing PR build/test checks remain under `MIX_ENV=test`; the preview-image workflow builds the full `MIX_ENV=preview` release; existing package/release workflows continue validating `MIX_ENV=prod`. Do not add a separate production compile gate to PR CI. Reconsider earlier production validation only if package-stage failures become recurrent.
- At runtime, any casing variant of `true` for `PREVIEW_QA_TOOLS_ENABLED` enables masquerade and mailbox access. Missing, blank, whitespace-padded, false, or malformed values disable those web QA capabilities without disabling `bin/seed`.
- A preview application server without web QA activation emits one bounded warning explaining how to set `PREVIEW_QA_TOOLS_ENABLED=true` for masquerade and mailbox access; releases built under other Mix environments and the dedicated seeding process do not. Preview email containment and release seeding remain available independently of this runtime flag.
- `PREVIEW_QA_SEED_SCENARIO=oli_torus_getting_started_course` selects the bundled scenario used by pull-request preview automation. It does not activate web QA capabilities and is independent of `PREVIEW_QA_TOOLS_ENABLED`.
- The preview deployment retains one fixed-name `restartPolicy: Never` seed Job with `backoffLimit: 0` and explicit CPU/memory requests and limits. A later Argo CD sync wave waits for the application Deployment—which includes baseline `release-setup` and its readiness probe—to become Healthy before invoking `bin/seed scenarios run --name oli_torus_getting_started_course` with discrete arguments and no shell interpolation. The completed Job remains the one-run marker across subsequent image updates and resyncs and is pruned with the pull-request preview namespace. Kubernetes owns logs and status; Torus persists no Job identity.
- No seed-history migration is required. Disabling the runtime flag invalidates active masquerade on the next request but does not undo seeded data.

## 12. Telemetry & Success Metrics
- CLI commands emit bounded structured logs and process exit status for operation, source type, scenario identifier or digest, duration, and aggregate result counts without YAML bodies or sensitive values.
- Kubernetes monitoring owns seed Job completion, failure, duration, and resource visibility. A failed one-shot Job requires operator inspection and fresh/reset data before another invocation.
- Audit masquerade start, stop, expiry, and invalidation with actor and target identifiers.
- Success means operators can prepare fresh QA environments through controlled shell/deployment interfaces with less implementation and operational surface than an in-application seed system.

## 13. Risks & Mitigations
- Shell operators can execute powerful scenario behavior: treat shell access as the privileged boundary, retain the preview-build/runtime-activation boundary, document that scenarios mutate real data, and keep the capability out of production images.
- A URL exposes internal or oversized content: accept only HTTP/HTTPS, apply bounded redirects/time/size, avoid logging credentials, and clean temporary files. Deployment network policy remains authoritative because a shell operator already has equivalent network access.
- Partial scenario mutation occurs before failure: return nonzero, report that partial changes may exist, and do not claim rollback.
- A partial `oli_torus_getting_started_course` failure leaves canonical data behind: disable automatic Job retries, report partial mutation, and require operators to recreate or deliberately reset the ephemeral preview data before rerunning.
- Masquerade leaks administrator privilege: separate actor and target identities, authorize only as the target except for stop, prohibit chaining, expire sessions, and test forged requests.
- An unsanitized production database clone or production credentials expose external integrations: preview instances support only fresh or explicitly sanitized databases and non-production runtime configuration. Email is contained through the local adapter; making production clones broadly safe requires a separate inventory and design covering all outbound effects and background work.
- Custom scenario hooks invoke external behavior: hooks execute with shell-equivalent trust, so the operator is responsible for their effects beyond application email sent through `Oli.Mailer`.

## 14. Open Questions & Assumptions
### Open Questions
None.

### Assumptions
- Anyone with deployment shell or IEx access is already a trusted operator capable of invoking privileged application code and database mutations.
- A separate deployment-management interface supplies authenticated shell access and records operator activity outside Torus.
- Provided project URLs are reachable from the running container and identify compatible Torus export archives.
- Seed inputs contain only synthetic QA data and are retained externally by the operator when reproducibility is required.
- User masquerade remains necessary for manual QA even though seed execution has no application UI.
- Preview instances use fresh databases or explicitly sanitized non-production copies and are not supplied production integration credentials. Unsanitized production database clones are unsupported by this feature.

## 15. QA Plan
- Automated validation:
  - Cover the Mix-environment/runtime-flag truth table, casing variants, startup warning, Docker build argument, and preview workflow policy. Existing production packaging remains unchanged.
  - Test release scenario listing, bundled and local-file execution, complete DSL compatibility, explicit YAML ownership, bounded output, failure exit codes, and partial-mutation reporting.
  - Test URL validation, redirects, timeouts, size bounds, download failures, archive ingest success/failure, author selection, log redaction, and temporary-file cleanup.
  - Exercise `bulk_create_enroll_users` and the replacement `simulate_progress` profile/cohort schema, deterministic assignments and responses, one DataShop session per learner, delivered course ordering, authentic native practice/assessment lifecycles, existing-history skipping, paced waits, fixed caps, compact state, and Stagehand migration.
  - Run `oli_torus_getting_started_course` once through the development and release interfaces on fresh data and verify its curriculum, activities, cohort, progress, gradebook state, bounded partial-failure reporting, and the absence of automatic retry or reconciliation machinery.
  - Confirm there is no workbench, seed route, Oban seed worker/queue, run-history schema, or startup-status endpoint.
  - Preserve Playwright fixture compatibility.
  - Cover masquerade authorization, target-only permissions, session lifecycle, auditing, safe redirects, and accessible banner coverage.
  - Verify every preview configuration uses `Swoosh.Adapters.Local` and sends no external email, while `/dev/mailbox` is exposed only with runtime activation and authentication as either the current system administrator or the original system-administrator actor in a valid active masquerade.
  - Confirm the implementation adds no preview-specific LTI grade-passback, Stripe, Cashnet, or broad production-clone safety behavior.
- Manual validation:
  - From a QA-capable image, list scenarios, run a bundled scenario, run custom YAML, and ingest a project URL through shell access.
  - Run `oli_torus_getting_started_course` through a disposable pull-request preview, verify ready-before-seed ordering and one execution, then verify a later image sync does not rerun it and closing the pull request prunes it.
  - Masquerade as representative instructor and learner users across application surfaces and stop safely.
  - Confirm production builds contain neither release seeding nor web QA capabilities, while a preview deployment without runtime activation still permits `bin/seed` but rejects masquerade and mailbox access.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes

## Decision Log

### 2026-09-15 - Make release seeding available without the web QA flag
- Change: Treat `bin/seed` invocation in a `MIX_ENV=preview` release as the low-level operational opt-in. Do not require `PREVIEW_QA_TOOLS_ENABLED` for CLI seeding. Continue requiring that flag for web-accessible masquerade and `/dev/mailbox` features.
- Reason: Seeding code and `bin/seed` are already absent from production releases, and invoking a release-shell command is an explicit privileged action. A second runtime switch adds no meaningful authorization boundary there, while web-accessible features still benefit from a deployment-level kill switch.
- Impact: Remove the runtime-enable check from `Oli.Seeding.CLI`, retain compile-time exclusion and shell authorization, narrow startup status and `Oli.PreviewQATools.Config` to web QA features, and update release commands, manifests, tests, and documentation. This supersedes the seeding portion of the 2026-09-09 runtime-activation decisions below.

### 2026-09-14 - Name and deploy the Getting Started course once
- Change: Formally name the bundled scenario `oli_torus_getting_started_course` and its design artifact `oli-torus-getting-started-course.md`. Treat it as a one-shot initializer for a fresh or deliberately reset preview database and set its Kubernetes Job to `backoffLimit: 0`. Retain the fixed-name completed Job across later image syncs, and do not add resume, reconciliation, completion markers, or seed-run persistence.
- Reason: Phase 4B intentionally skips learners with existing history and leaves committed work in place after interruption. Retrying a partially mutated scenario would either duplicate domain data or require the reconciliation subsystem removed during simplification.
- Impact: Stable scenario references remain useful within one run but do not imply cross-run idempotency. Operators inspect a failed Job and recreate or reset preview data before starting another seed Job. The retained Job prevents an ordinary Argo CD resync from replaying the scenario and is removed with its ephemeral namespace. This supersedes the earlier one-retry and release-derived Job-name portions of the deployment Job decision below.

### 2026-09-09 - Preserve mailbox access during administrator masquerade
- Change: Treat `/dev/mailbox` as the only actor-authorized exception besides stopping masquerade. A valid original system-administrator actor may inspect the mailbox while ordinary application authorization continues to use only the target user.
- Reason: Administrators need to inspect captured QA email without ending the learner or instructor session under test.
- Impact: Mailbox authorization uses a dedicated route-local check of the original actor. It does not replace `current_user` or grant access to any other administrator route, API, LiveView, navigation, data, or mutation.

### 2026-09-09 - Adopt a standalone `MIX_ENV=preview` release
- Change: Build preview images with `MIX_ENV=preview`; add a standalone `config/preview.exs` that imports neither `prod.exs` nor `dev.exs`; use the Mix environment as the compile-time capability boundary and retain `PREVIEW_QA_TOOLS_ENABLED` only for runtime activation of web QA features.
- Reason: Preview has a coherent release-level profile—non-delivering email and compiled QA tooling—but little in `prod.exs` warrants inheritance or a shared configuration layer. Explicitly owned duplication is clearer and prevents future production configuration changes from silently altering previews; discoverable build documentation records the intended relationship.
- Evidence: Approved reconsideration on 2026-09-09 after auditing current `Mix.env()` branches, dependency selectors, Docker release paths, and Elixir's compile/runtime configuration boundaries.
- Impact: The Docker build becomes environment-parameterized, preview workflows select `preview`, production remains the default, applicable production-shaped settings are copied intentionally into `preview.exs`, production-like Mix branches include `:preview`, and `guides/process/building.md` documents how each environment is built and configured. No new production PR compile or configuration-drift gate is introduced.

### 2026-09-09 - Contain email and exclude broad production-clone safety
- Change: Every preview release overrides outbound email with `Swoosh.Adapters.Local` and exposes `Plug.Swoosh.MailboxPreview` only with runtime enablement and system-admin authentication. Remove preview-specific LTI grade-passback, Stripe, and Cashnet suppression.
- Reason: Normal QA workflows readily emit email, while fresh preview databases lack the configuration needed for the other integrations. Selectively suppressing a few integrations would not make an unsanitized production clone safe and would imply incomplete protection.
- Evidence: Approved scope reduction after distinguishing ordinary preview behavior from the broader risks of attaching production database clones.
- Impact: FR-010 and AC-025 through AC-026 cover email only. Preview instances require fresh or explicitly sanitized databases and non-production credentials; production-clone safety is a separate future design.

### 2026-09-09 - Define masquerade layout coverage and LTI behavior
- Change: Require the banner in `default`, `workspace`, `delivery`, `delivery_student_dashboard`, `delivery_dashboard`, authenticated LiveView, and authenticated `chromeless` surfaces. Exclude `delivery_from_payment` and `lti`; clear or reject masquerade when entering a new LTI login/launch flow.
- Reason: `default` is the general browser root and can render authenticated masqueraded pages. `delivery_from_payment` is a narrow Cashnet callback response without restored user identity, while LTI establishes a fresh external identity that must not be combined with an existing masquerade.
- Evidence: Approved architecture decision after tracing router pipelines, Cashnet callbacks, and LTI entry points on 2026-09-09.
- Impact: Layout-matrix tests cover the required interactive surfaces and assert that LTI entry clears/rejects masquerade; Cashnet callback and LTI root layouts do not need the banner.

### 2026-09-09 - Define the deployment seed Job contract
- Change: In pull-request previews, create a fixed-name retained seed Job in a later Argo CD sync wave than the application Deployment. Application health proves that baseline `release-setup` and server readiness completed. Pass `oli_torus_getting_started_course` as a discrete argument to `bin/seed scenarios run --name <scenario>`, use `restartPolicy: Never`, explicit resources, and `backoffLimit: 0`, and preserve the completed pod template across later image updates.
- Reason: The contract provides deterministic readiness ordering and a one-run namespace marker without coupling Torus to Kubernetes APIs or storage.
- Evidence: Approved architecture decision on 2026-09-09.
- Impact: Kubernetes owns stdout/stderr, process-exit observation, Job status, and namespace-scoped retention. Torus persists no Job identity or seed result.

### 2026-09-09 - Name the release seeding interface `bin/seed`
- Change: Add a dedicated release-overlay executable with `bin/seed scenarios list`, `bin/seed scenarios run --name|--file`, and `bin/seed projects ingest --url --author` subcommands.
- Reason: A dedicated wrapper provides clean operator syntax and stable argument parsing while delegating to the supported generated `bin/oli eval` mechanism, consistent with the existing `bin/migrate` overlay pattern.
- Evidence: Approved architecture decision on 2026-09-09.
- Impact: The CLI rejects unknown options, missing values, extra positional arguments, and simultaneous `--name`/`--file` inputs with usage text and a nonzero exit. Underlying Elixir functions remain callable from IEx.

### 2026-09-09 - Reduce seeding to a privileged release CLI
- Change: Remove the admin seed workbench, Oban seed scheduling, seed-run persistence, YAML audit snapshots, deployed-safe directive allowlist, and seed HTTP/status APIs. Provide a synchronous release CLI that lists bundled scenarios, runs bundled or custom YAML, and ingests project archives from reachable URLs. Kubernetes uses the same CLI.
- Reason: Shell access is already a privileged operational boundary. Following established development-seeding practice avoids duplicating authorization, asynchronous orchestration, persistence, and UI systems inside Torus.
- Evidence: Approved scope revision after reviewing GitLab's CLI-based development seeds, Data Seeder, and Rake tasks.
- Impact: Replaces the previous seeding architecture and requirements while retaining the bundled Getting Started course, scenario extensions, preview build boundary, web QA runtime activation, Playwright independence, and user masquerade.

### 2026-09-09 - Retain user masquerade for manual QA
- Change: Keep system-administrator masquerade even though seed execution becomes CLI-only.
- Reason: Manual QA still requires efficient inspection of generated learner and instructor experiences.
- Evidence: Product clarification on 2026-09-09.
- Impact: Session security, actor/target audit attribution, authorization checks, accessible warning UI, and stop behavior remain in scope.

### 2026-09-09 - Require YAML-defined execution ownership
- Change: CLI-executed scenarios establish author and institution ownership within YAML through creation/references, restricted lookup, or explicit configured-default selectors; implicit first-record and generated-default ownership are prohibited.
- Reason: The executed YAML should remain self-describing even without persistent Torus run history.
- Evidence: Approved architecture decision after reviewing current Playwright and scenario behavior.
- Impact: Adds ownership selectors and validation to the release execution path.

### 2026-09-09 - Separate preview compilation from runtime activation
- Change: `MIX_ENV=preview` controls compile-time inclusion. At the time of this decision, `PREVIEW_QA_TOOLS_ENABLED` activated every compiled QA capability; the 2026-09-15 decision above supersedes that behavior for CLI seeding and retains it only for web QA features.
- Reason: Environment identity and operator activation are separate concerns. This keeps QA code out of production releases without overloading one environment variable as both a build selector and runtime switch.
- Evidence: Approved architecture decision.
- Impact: Requires `config/preview.exs`, parameterized Docker release paths, a one-time review of production-like environment branches, runtime gating, warning behavior, configuration tests, and updated build documentation.

### 2026-09-09 - Move startup seeding to Kubernetes and keep Playwright self-seeding
- Change: Run `oli_torus_getting_started_course` through the retained later-wave Kubernetes Job and preserve Playwright's existing per-spec scenario setup.
- Reason: Kubernetes owns deployment-time execution and Playwright already owns isolated test data.
- Evidence: Approved architecture revision and codebase analysis.
- Impact: No web-runtime startup coordinator or Playwright startup profile is added.
