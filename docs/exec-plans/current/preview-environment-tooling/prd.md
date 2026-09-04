# Preview Environment Seeding and User Masquerade - Product Requirements Document

## 1. Overview
Provide explicitly enabled development and QA deployments with realistic, repeatable sample data and safe system-administrator masquerading. The capability will extend `Oli.Scenarios` to cover realistic bulk user enrollment and learner-progress simulation, replacing the separate Stagehand prototype with one declarative workflow system. It will support automated initialization and an administrator-facing runtime workflow and remain unavailable unless a deployment opts in through runtime configuration.

## 2. Background & Problem Statement
Pull-request previews begin with only the baseline data from `priv/repo/seeds.exs`. Developers, QA engineers, and Playwright suites must therefore recreate representative projects, sections, users, enrollments, and learner progress before meaningful review. Local and long-lived QA systems are easier to use because they have accumulated this data.

Torus already has a production-facing `Oli.Scenarios` API for executing YAML workflows against real application contexts. The separate Stagehand prototype provides two useful capabilities that scenarios do not fully cover today: bulk creation/enrollment of users with realistic synthetic names and simulated learner progress through a section. Maintaining both systems would create overlapping setup APIs and two safety boundaries. Consolidating those behaviors into scenario directives provides one validated, composable, testable execution model, but exposing it in a deployed application still introduces material authorization, arbitrary-execution, repeatability, concurrency, and audit risks. The same non-production deployments also need a low-friction way for an administrator to verify seeded learner and instructor experiences without managing multiple browser sessions.

## 3. Goals & Non-Goals
### Goals
- Seed fresh, opted-in preview and sandbox deployments with deterministic, realistic data through supported Torus domain operations.
- Extend and harden the existing scenario DSL/runtime with the two useful Stagehand workflows, then retire Stagehand as a separate public data-generation API.
- Let authorized system administrators load predefined seed scenarios, edit or replace their YAML text, validate and execute the resulting definition at runtime, and inspect outcomes.
- Let system administrators temporarily act as seeded users while preserving the administrator as the accountable actor and making the altered identity unmistakable.
- Make every capability deny-by-default at runtime, observable, resource-conscious, and safe under retries or concurrent deployment startup.
- Keep deployment integration generic enough for any deliberately enabled development or QA deployment, while initially targeting pull-request previews and sandboxes.

### Non-Goals
- Enabling seeding or masquerade by inferred environment names such as `preview`, `sandbox`, `dev`, or `prod`.
- Replacing the minimal baseline installation responsibilities of `priv/repo/seeds.exs`.
- Providing these tools to content authors, instructors, learners, institution administrators, or unauthenticated callers.
- Supporting production data migration, production customer-data generation, destructive environment reset, or deletion/rollback of arbitrary scenario-created records.
- Turning the scenario DSL into a general remote-code-execution facility; unrestricted hooks and filesystem paths are excluded.
- Guaranteeing that every existing test scenario is safe, meaningful, or idempotent as a deployed seed definition.
- Replacing browser-level Playwright setup where a test specifically needs to verify setup UI behavior.
- Preserving backward compatibility for undocumented Stagehand prototype entry points after their scenario equivalents are available and repository call sites are migrated.

## 4. Users & Use Cases
- Developers and reviewers: open a new pull-request preview and immediately inspect representative authoring, delivery, and learner states.
- QA engineers: select and run an approved seed scenario, review its result, and masquerade as a generated user for manual verification.
- Playwright suites: rely on a configured startup seed profile and wait for a machine-readable terminal result through an authenticated read-only status interface.
- System administrators on enabled deployments: load a predefined scenario or paste YAML into an editor, modify, validate, and execute it; inspect results; and start or stop a masquerade session.
- DevOps operators: independently choose whether the capability is available, which startup seed profile runs, and which deployed seed definitions are available.
- Security and operations reviewers: audit who initiated seed runs and masquerades, what definition/version was used, and whether execution succeeded.

## 5. UX / UI Requirements
- Add a system-administrator seeding workbench under the existing admin navigation, visible only when the deployment capability is enabled.
- Show available seed definitions with name, description, source, version or digest, last validation/run status, initiator, timestamps, duration, and a concise created-entity/error summary.
- Provide schema validation before execution and require explicit confirmation for a runtime run; disable execution while the same definition is already running unless its declared policy permits another run.
- Reuse the existing `OliWeb.Common.Monaco` component and `MonacoEditor` LiveView hook used by revision history for the YAML editor rather than introducing another code-editor integration. Configure it for YAML syntax, editable working-copy updates, and scenario validation feedback. It can be populated from a predefined scenario or completely replaced with pasted custom YAML; loading a predefined scenario never changes the codebase definition.
- Treat YAML text itself as the portable format: administrators can copy and paste it to or from external storage, while Torus provides no custom-definition persistence, file upload, or file download workflow.
- Do not render secrets, full learner responses, session tokens, unrestricted stack traces, or previously submitted custom YAML in run history.
- Add an `Act as user` action to the existing admin user detail surface when enabled and authorized, plus a persistent, high-contrast magenta treatment and message on every masqueraded page that identifies the target user and provides an immediate `Stop acting as user` action.
- The masquerade indicator and controls must be keyboard accessible, screen-reader labeled, and must not rely on color alone.
- Preserve a safe return destination when masquerade ends; if the target cannot access the current route, redirect through the normal authorization flow rather than granting administrator access to the target identity.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Security: both server-rendered visibility and every invocation path must independently require the runtime opt-in and a current system-administrator identity. Disabling the flag must remove routes/actions and invalidate active masquerade state on the next request.
- Accountability: authorization and audit decisions must retain the original administrator identity separately from the effective masqueraded user; application code must never promote the target user's privileges from the actor's admin role.
- Input safety: deployed execution must accept only schema-valid directives from configured sources and an explicit runtime-safe directive/function allowlist. Path traversal, remote URLs, unrestricted `use`, and arbitrary hook invocation must be rejected. Custom YAML uses existing application request-body protections rather than a seed-specific size cap.
- Reliability: startup seeding and runtime runs must execute as Oban jobs with durable run state, deterministic terminal outcomes, bounded retries, and cross-node concurrency protection. Seed failures do not prevent the web application from becoming healthy. Seed jobs have no execution timeout.
- Repeatability: seed definitions must declare an execution policy such as once-per-database, once-per-definition-digest, or explicitly repeatable. Reconciliation must not silently duplicate data after pod restarts.
- Performance: seed work must run outside latency-sensitive web/LiveView processes, expose progress, and use controlled batching and modest internal concurrency to avoid exhausting preview/sandbox CPU, memory, database connections, or job capacity. The initial product contract sets no hard maximum for directives, users, learners, pages, attempts, or queued jobs.
- Privacy: predefined scenarios and custom YAML must use synthetic identities and contain no production-derived personal data or credentials.

## 9. Data, Interfaces & Dependencies
- Reuse `Oli.Scenarios` parsing, schema validation, execution state, and summary APIs as the declarative workflow boundary. Introduce an explicit deployed-seeding policy layer rather than invoking arbitrary scenario files directly from a controller or LiveView.
- Add scenario directives for (1) bulk creation and enrollment of instructors/learners with realistic synthetic names and (2) simulated progress for selected learners through a section. Move reusable implementation logic behind scenario-owned services where needed; do not expose the existing Stagehand module as a second deployed execution path.
- Add `bulk_users` with required `name` and `section`; optional non-negative `instructors` and `students` counts defaulting to `0`; and an optional integer `random_seed`. Require at least one non-zero role count. The section may be a named scenario section or a supported existing-section reference.
- `bulk_users` creates a stable group reference and member references such as `<group>_instructor_1` and `<group>_student_1`, realistic synthetic names, system-defined collision-safe identities, and emails under `seed.example.invalid`. The initial directive does not permit custom email domains, identity formats, or name providers.
- Add `simulate_progress` with required `section` and `users`; optional `percent_complete` and `percent_correct` values from `0.0` to `1.0`, each defaulting to `1.0`; and an optional integer `random_seed`. `users` accepts a `bulk_users` group reference or an explicit list of scenario user references.
- `simulate_progress` uses controlled batched concurrency. With a random seed, page selection and responses are deterministic. Unsupported pages or activity types produce structured warnings and are skipped; unexpected execution failures produce structured errors. Multiple directives can target distinct groups to create varied cohorts.
- Retain only explicitly allowlisted, non-mutating runtime-safe assertions as post-seed verification. Execute them in normal scenario order; any failure marks the job failed and reports that preceding committed mutations were not rolled back. Reject non-certified assertions and arbitrary hooks. Permit reusable file composition only for predefined codebase-owned scenarios; pasted custom YAML cannot resolve `use` against arbitrary files.
- Use Oban for startup and administrator-requested seed execution. After application startup and database migration readiness, a startup coordinator enqueues the configured predefined profile without blocking application readiness.
- Add durable seed-run records associated with their Oban job and sufficient for predefined identity when applicable, source type, content digest/version, requested policy, actor, status, attempt/retry information, timestamps, summary, and redacted failure details. Do not persist custom YAML bodies as reusable definitions or in run history.
- Support deployment-bundled, runtime-safe predefined scenarios plus transient custom YAML working copies. A configured startup profile selects only a predefined scenario; merely enabling the capability does not imply automatic execution.
- Ship two initial codebase-owned profiles assembled from reusable scenario YAML modules:
  - `review_demo` creates one realistic institution; a content-rich project with modules, basic and graded pages, supported activities, and objectives; a publication, product, and section; two instructors; approximately 20 learners; varied not-started, partial, complete, mostly-correct, mostly-incorrect, and mixed progress; and representative gradebook, discussion, gating, and analytics data where runtime-safe scenario support exists.
  - `playwright_smoke` creates one compact project, publication, and section; one instructor; three learners in not-started, in-progress, and completed states; and only the content/activity data needed for fast deterministic smoke setup.
- Give important seeded entities stable scenario references and collision-safe synthetic emails under the reserved `seed.example.invalid` domain. With a supplied random seed, realistic display-name generation and progress outcomes must be deterministic. Predefined YAML must not contain shared passwords or login credentials.
- Return a bounded profile result summary containing stable user references, names, roles, section slugs, and relevant content slugs so administrators and automation can locate created entities. Manual QA uses masquerade to access seed users; Playwright uses its existing authenticated setup and stable identifiers/emails rather than seed-user passwords.
- Provide a narrow application service shared by startup orchestration and the admin workbench. Provide a purpose-authenticated, read-only automation status endpoint so Playwright can poll the configured startup profile and content digest until success or failure. The initial release must not provide an HTTP endpoint for triggering seed execution.
- Limit automation status responses to run identifier, predefined profile identifier, content digest, status, timestamps, attempt count, and stable identifiers/slugs produced by a successful run. Do not expose YAML bodies, arbitrary historical runs, credentials, or unrestricted failure details, and use non-enumerable responses for unknown runs and unauthorized callers.
- Represent masquerade as signed server-side session state containing the original administrator identity, effective target user, start time, and expiry/reference. Audit records must capture start, stop, expiry, actor, target, and request context without storing tokens.
- While masquerading, evaluate normal application authorization exactly as the target user. Do not inherit the original actor's administrator privileges; retain only the narrowly scoped ability to stop masquerading. Permit administrator accounts as targets and prohibit chained masquerade until the current session is stopped.
- Do not add an action-specific masquerade blocking matrix in the initial scope. Actions performed as the target are real, non-rollback mutations in the disposable environment. Preview/sandbox deployment configuration is responsible for disabling or safely redirecting payments, outbound email, LTI grade passback, and other external integrations for all QA activity.
- Deployment configuration must be expressible as ordinary runtime environment/config-map values so preview and sandbox manifests can opt in explicitly. Deployment repository paths and workstation-specific locations are not part of this product contract.

## 10. Repository & Platform Considerations
- Keep domain orchestration in `lib/oli/`; use `lib/oli_web/` for authorization, session handling, LiveView interaction, and rendering.
- Scenario execution currently operates synchronously and can create default authors/institutions; deployed seeding must select explicit seed ownership/context and must not accidentally create throwaway defaults.
- Scenario `use` resolves filesystem-relative paths and scenario hooks can invoke functions. Both require a constrained deployed-runtime contract before administrator-authored YAML is safe.
- The existing Monaco component/hook already supplies LiveView value exchange, resizing, and configurable language/options. Extend or configure that shared integration for YAML and scenario diagnostics; do not couple seed execution authorization or server-side validation to client-side Monaco behavior.
- Stagehand currently targets an existing section and performs concurrent learner simulation. Treat it as source material for scenario-owned behavior: migrate its useful logic and call sites, cover the replacement directives, and remove or deprecate the standalone module so the seeding service cannot bypass scenario validation and execution policy.
- Respect Torus institution, publication, enrollment, role, and immutable published-content boundaries by using existing contexts and scenario handlers.
- Execute non-trivial simulations asynchronously in a dedicated Oban queue with concurrency `1` per deployment database. Use database-backed uniqueness keyed by deployment database, profile identifier or custom content digest, and declared execution policy to coordinate requests across clustered nodes and rolling deployments. Do not impose a seed-job execution timeout or a separate pending-job cap.
- Cover domain policy and orchestration with ExUnit, admin interaction with LiveView tests, cross-domain seeded workflows with `Oli.Scenarios`, and the persistent masquerade treatment across representative server-rendered, LiveView, and mounted React surfaces.
- Implementation changes require the repository's security, performance, Elixir, UI, and requirements review lenses.
- Jira remains the issue-tracking system of record; no Jira item is created or edited by this PRD.

## 11. Feature Flagging, Rollout & Migration
- Use `DEV_QA_TOOLS_ENABLED=true` as the single deny-by-default runtime capability flag gating automated seeding, runtime seed administration/automation, and masquerade at server-side route, service, and session boundaries. Missing, blank, malformed, or any value other than exactly `true` means disabled.
- Use the optional `DEV_QA_SEED_PROFILE=<predefined-scenario-id>` runtime variable to select a predefined scenario for automatic startup seeding. The capability flag must also be enabled; a profile value cannot enable the capability by itself.
- An enabled capability with no startup profile exposes the administrator tools but performs no automatic seeding. An unknown profile records and surfaces a configuration error and performs no seed execution.
- Startup seeding is requested only after the application starts and migrations are ready, runs as an Oban job, and does not block application readiness. A terminal failure remains visible but does not make the deployment unhealthy.
- Initial rollout targets explicitly configured pull-request preview and sandbox deployments, followed by selected development/QA deployments after audit, concurrency, failure, batching, and resource-usage validation.
- No environment name, Mix environment, hostname, ingress policy, or existing seed data may implicitly enable the capability.
- The initial automation API is status-only. Administrators may execute predefined or custom YAML through the workbench; remote HTTP-triggered execution is deferred until a concrete automation need cannot be met by configured startup profiles.
- Do not require a second application-level environment-classification variable; any deliberately configured development or QA deployment may use the capability. Deployment-policy validation must prohibit `DEV_QA_TOOLS_ENABLED=true` in production configuration. Application-side checks remain authoritative even when ingress is authenticated.
- Schema/data migrations for run history must be backward compatible while the flag is disabled. Disabling the flag leaves historical audit/run records intact and inaccessible except through existing authorized operational tooling.

## 12. Telemetry & Success Metrics
- Emit bounded telemetry/logs for seed validation and execution request, start, completion, failure, rejection, duration, definition digest/profile, execution source, and aggregate entity counts; exclude YAML bodies, personal data, answers, and tokens.
- Emit audit events for predefined-scenario load, YAML validation, runtime seed execution, and masquerade start/stop/expiry with original actor and effective target identifiers. Audit data must identify custom executions by digest rather than retain their YAML bodies.
- Measure startup seed completion/failure rate and duration, runtime run success rate and duration, rejected unauthorized/disabled requests, duplicate/concurrent runs prevented, and active masquerade starts/stops/expirations.
- Measure aggregate directives, users, learners, pages, attempts, batching/concurrency behavior, and queue pressure so future workload limits are based on operational evidence.
- Product success signals are reduced time from deployment readiness to meaningful review, fewer manual setup steps in preview QA, and reliable Playwright setup from a documented seed profile. Establish a baseline during rollout before setting numeric targets.

## 13. Risks & Mitigations
- Runtime scenario execution becomes arbitrary or resource-intensive execution: prohibit unrestricted hooks and paths, allowlist the new bulk-user and progress directives with strict schemas, validate positive numeric inputs, serialize jobs, batch internal work, and execute through one policy-enforcing service. Use telemetry to determine whether evidence-based limits are needed later.
- Seed retries create duplicate or conflicting records: persist definition digests and run policy, serialize matching runs, use stable identifiers/idempotent handlers where possible, and make repeat behavior explicit.
- Startup work delays or destabilizes deployment: use durable asynchronous execution, non-blocking readiness semantics, a serialized queue, controlled batching, workload telemetry, and observable non-fatal failure.
- Masquerade causes privilege confusion or unaudited mutation: preserve original actor/effective user separately, authorize before switching, prohibit chaining, expire state, show a persistent indicator, and audit lifecycle events.
- Masqueraded activity reaches a real external system: require preview/sandbox deployments to disable or safely redirect payments, email, LTI grade passback, and comparable integrations. Add action-specific masquerade restrictions later only for demonstrated risks.
- The flag is accidentally enabled on a sensitive deployment: require an explicit runtime value, enforce server-side gates everywhere, add deployment-policy validation, and generate a conspicuous startup warning/telemetry signal when enabled.
- Pasted custom YAML leaks sensitive data or invokes unsafe behavior: apply existing request-body protection, validate schema and runtime policy before execution, require synthetic identities, redact output, and do not retain the YAML body in reusable definitions or run history.
- Existing scenarios rely on test assumptions or non-repeatable assertions: certify a smaller deployed-safe catalog and add compatibility metadata rather than exposing all files under `test/scenarios/`.

## 14. Open Questions & Assumptions
### Open Questions
- None.

### Assumptions
- The capability serves synthetic, disposable development/QA data; no production-derived data will be imported.
- Pull-request preview and sandbox deployment configuration can supply explicit non-secret runtime values and approved seed definitions or references.
- A system administrator is an existing Torus platform-level administrator, not merely an institution or section administrator.
- The original administrator remains authenticated while masquerading, but normal application authorization evaluates the effective user except for the narrowly scoped stop-masquerade control and audit attribution.
- Masquerade introduces no initial action-specific deny list. Permitted target-user actions create real changes that are not automatically rolled back, and deployment-level configuration contains external side effects.
- Predefined scenarios are codebase-owned and immutable at runtime; loading one creates a transient editable copy. Custom YAML is retained only for the active editing/execution workflow and is not saved as a reusable Torus definition.
- Seed execution is additive. Environment reset and general rollback are separate operational concerns.
- Stagehand has no external compatibility commitment that prevents migrating repository call sites and retiring its standalone API.
- Initial predefined profiles are `review_demo` for rich human QA and `playwright_smoke` for fast deterministic automation; both are composed from reusable YAML modules.

## 15. QA Plan
- Automated validation:
  - Verify every route, LiveView event, service entry point, startup trigger, and automation interface rejects access when the runtime flag is absent, malformed, or disabled.
  - Verify non-system-admin and unauthenticated requests cannot view predefined scenarios, validate or execute YAML, inspect runs, or start/stop masquerade, including forged direct requests.
  - Exercise schema-safe and unsafe scenario inputs, directive/hook/path allowlists, existing request-size protection, positive numeric validation, redaction, complete historical job/run listing, retry policies, serialized execution, controlled batching, clustered startup, and pod restart behavior.
  - Verify long-running jobs are not terminated by a seed-specific execution timeout and queued jobs are not rejected by a seed-specific pending-job cap.
  - Run representative scenario seed profiles through real contexts and verify projects, publications, sections, realistically named users, enrollments, attempts, progress distributions, and summaries without fixture/factory domain setup.
  - Verify deterministic bulk-user identities and progress outcomes when a random seed is supplied, variable outcomes when it is omitted, collision handling, supported/unsupported activities, controlled batching, and migration of existing Stagehand call sites.
  - Cover masquerade lifecycle, expiry, logout, target deletion/disablement, session renewal, no chaining, actor/effective-user separation, audit attribution, and invalidation after the flag is disabled.
  - Verify target-user permissions apply unchanged—including for an administrator target—while the original actor contributes no inherited privilege beyond stopping masquerade; confirm permitted changes persist after masquerade ends.
  - Verify preview and sandbox deployment configuration disables or safely redirects real payments, outbound email, LTI grade passback, and other approved external integrations independently of masquerade.
  - Use LiveView/component tests for the admin workbench and accessible persistent indicator, plus targeted frontend tests where mounted React layouts participate.
  - Verify the shared Monaco integration loads predefined YAML, accepts pasted and edited YAML, preserves text across relevant LiveView interactions, displays syntax/server-validation feedback, and cannot bypass server-side validation by forging editor events.
  - Validate enabled and disabled preview/sandbox deployment manifests and configuration policy without embedding repository-specific filesystem locations in application documentation.
- Manual validation:
  - Deploy a fresh explicitly enabled preview and sandbox, confirm the selected profile runs once, inspect representative author/instructor/learner data, restart/roll the deployment, and confirm no unintended duplication.
  - Load and edit a predefined scenario, paste and run a completely custom scenario, copy its YAML text for use elsewhere, and confirm useful redacted validation, error, and completion states without any custom-definition save, upload, or download workflow.
  - Act as instructor and learner seed users across authoring/delivery surfaces, confirm permissions match the target, confirm the magenta actor indicator persists across full navigation, LiveView navigation, and mounted apps, then stop and return safely.
  - Deploy with the capability omitted/disabled and confirm there are no seed admin routes, automation endpoints, startup runs, masquerade actions, or accepted stale masquerade sessions.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
