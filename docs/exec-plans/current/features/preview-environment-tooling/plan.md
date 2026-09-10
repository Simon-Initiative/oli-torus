# Preview Environment Seeding and User Masquerade - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/features/preview-environment-tooling/prd.md`
- FDD: `docs/exec-plans/current/features/preview-environment-tooling/fdd.md`
- Requirements: `docs/exec-plans/current/features/preview-environment-tooling/requirements.yml`

## Scope

Deliver a production-shaped `MIX_ENV=preview` release with three coordinated capabilities: a synchronous `bin/seed` interface for scenario execution and project ingestion, system-administrator user masquerade for manual QA, and non-delivering preview email with a protected mailbox. Extend `Oli.Scenarios` with deterministic bulk-user and learner-progress operations, provide an idempotent bundled `review_demo` profile, and connect that profile to the post-migration Kubernetes workflow.

The implementation must preserve the compile-time preview boundary and deny-by-default runtime activation, existing publication and authorization boundaries, existing Playwright-owned scenario setup, and the ordinary production release default. It must not add a seed UI or HTTP API, Oban seed work, seed-run persistence, YAML snapshots, broad external-integration suppression, or a claim that unsanitized production database clones are safe.

## Clarifications & Default Assumptions

- `MIX_ENV=preview` is the sole compile-time capability boundary. `PREVIEW_QA_TOOLS_ENABLED` activates compiled seeding, masquerade, and mailbox access only when its value equals `true` case-insensitively; whitespace-padded and all other values remain disabled.
- While masquerade is active, normal application authorization has exactly the target user's capabilities. No general system-administrator route, LiveView, API, navigation, data access, or mutation may authorize from the actor identity. The only actor-authorized exceptions are stopping masquerade and accessing the preview mailbox at `/dev/mailbox`.
- `config/preview.exs` is standalone and intentionally duplicates only applicable production-shaped settings. It imports neither `prod.exs` nor `dev.exs`.
- Preview email always uses `Swoosh.Adapters.Local`, independently of runtime activation. Other outbound integrations remain unchanged and require fresh or explicitly sanitized data plus non-production credentials.
- Shell or IEx access is the authorization and audit boundary for seeding. The CLI exposes the complete existing scenario DSL and is not an input sandbox.
- CLI scenario execution adds an explicit-ownership mode without changing the defaults used by existing tests and Playwright. Author and institution must be established in YAML before an ownership-dependent directive executes.
- Scenario and ingest operations retain their existing transaction boundaries. Once scenario execution begins, a failure may leave partial mutations and must say so without claiming rollback.
- Deployment manifests may be owned outside this repository. If implementation confirms that boundary, the Torus change must define and test the command contract and provide the exact manifest change for the owning deployment repository; the phase gate requires evidence that the owning deployment path was updated before rollout.
- No Jira write is part of this plan. If delivery tracking requires Jira changes, draft the exact proposed changes and obtain explicit user approval before using the `jira` CLI.

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
  - [x] Update `guides/process/building.md` with the purposes and workflows for `test`, `prod`, and `preview`, standalone configuration ownership, compile-time versus runtime configuration, activation syntax, local-email containment, and the unsupported production-clone boundary.
- Testing Tasks:
  - [x] Add unit tests for the full environment/flag truth table, including casing variants and missing, blank, whitespace-padded, false, malformed, hostname, profile, and unrelated-flag inputs.
  - [x] Capture logs to prove the preview-disabled warning is emitted once and other environments do not emit it.
  - [x] Add configuration assertions that preview uses `Swoosh.Adapters.Local` whether the runtime flag is enabled or disabled.
  - [x] Add static workflow/Docker assertions for the `prod` default, both preview build arguments, and consistent environment-specific release paths.
  - [x] Compile or build the preview release through the existing preview-image path and retain existing production packaging as the production-environment gate.
  - Command(s): `mix test <targeted PreviewQATools configuration and build-policy tests>`; `MIX_ENV=preview mix compile`; `mix format`; preview-image workflow build.
- Definition of Done:
  - Preview compiles with production-shaped settings and local-only mail, production remains the Docker default, runtime activation is deny-by-default, startup signals are bounded, and the environment contract is documented.
- Gate:
  - AC-001 through AC-004 and AC-025 have automated evidence; a preview release builds successfully; review confirms no runtime value can add QA code to a non-preview release.
- Dependencies:
  - None.
- Parallelizable Work:
  - Docker/workflow changes, build documentation, and configuration-test scaffolding can proceed in parallel after the environment audit agrees on the production-like branch matrix.

## Phase 2: Build the Synchronous Scenario Release Interface

- Goal: Provide a bounded, release-compatible CLI for listing and synchronously running bundled or operator-provided scenarios with explicit execution ownership.
- Requirements: FR-002; AC-005, AC-006, AC-007, AC-008, AC-009.
- Tasks:
  - [x] Add a release-only `Oli.Release.PreviewQATools` dispatcher and `rel/overlays/bin/seed` wrapper following the existing `rel/overlays/bin/migrate` pattern; fail before mutation unless effective preview enablement is active.
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
  - `bin/seed scenarios list` and both run forms execute synchronously in an enabled preview release, expose the full scenario engine, enforce YAML-defined ownership, redact sensitive input, and return reliable status without new application-managed state.
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
  - [ ] Add `projects ingest --url <http(s)-url> --author default_admin|email:<email>` parsing and explicit unique active-author resolution.
  - [ ] Implement `Oli.Release.PreviewQATools.ProjectIngest` with HTTP/HTTPS-only scheme validation, finite connection/receive timeouts, bounded redirects, configured maximum bytes, and streaming into a uniquely created temporary directory.
  - [ ] Invoke `Oli.Interop.Ingest.ingest/2` without reimplementing archive import, and report only the bounded identity of the created project.
  - [ ] Guarantee temporary-file and directory cleanup in success, download failure, size/redirect/timeout failure, invalid archive, author failure, and ingest failure paths.
  - [ ] Sanitize errors and telemetry so URL credentials, query secrets, response bodies, archive contents, and author-sensitive values do not reach routine logs.
- Testing Tasks:
  - [ ] Use a controlled local HTTP server to cover HTTP and HTTPS acceptance, invalid schemes, redirects and redirect loops, slow responses, connection/receive timeout, exact/oversized byte limits, truncated downloads, and non-success status codes.
  - [ ] Test author selection, successful `Oli.Interop.Ingest` integration, ingest failures, deterministic exit status, bounded result output, and cleanup after every outcome.
  - [ ] Capture logs for credential and archive-content redaction and verify network-policy ownership is documented without adding an application SSRF destination allowlist.
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
  - [ ] Define and document `bulk_users` and `simulate_progress` directive schemas, validation, stable-reference rules, optional random seed behavior, structured warnings, and failure semantics.
  - [ ] Extract reusable enrollment and progress behavior from `lib/oli/utils/stagehand.ex` and its supporting modules into scenario-owned services using existing account, section, enrollment, attempt, and evaluation contexts.
  - [ ] Implement collision-safe synthetic instructor/learner identities and deterministic reference generation that remains stable across a seeded retry.
  - [ ] Implement progress simulation using preloaded section inputs, fixed-size batches, modest supervised concurrency, and bounded per-task timeouts; aggregate unsupported activity/content warnings without unbounded learner detail.
  - [ ] Register parser, validator, directive type, handler, and documentation support using the established `Oli.Scenarios` extension points.
  - [ ] Migrate repository Stagehand call sites to scenario-owned behavior, then remove the standalone deployed Stagehand API and dead helper state after parity is proven.
- Testing Tasks:
  - [ ] Add parser/validator tests plus integration scenarios for valid and invalid attributes, role/enrollment creation, stable references, identity collisions, deterministic seeded progress, and different-seed variation.
  - [ ] Cover supported activity completion, grading/progress results, unsupported content warnings, task timeout/failure aggregation, and bounded concurrency without N+1 section loading.
  - [ ] Run affected existing Stagehand and scenario suites before removal, then add a repository check proving no separate deployed Stagehand call path remains.
  - Command(s): `mix test <bulk_users, simulate_progress, and migrated Stagehand tests>`; `mix test test/scenarios`; `mix format`.
- Definition of Done:
  - Both directives are normal scenario operations with deterministic references and bounded execution, all call sites use scenario-owned behavior, and Stagehand is no longer an independent deployed interface.
- Gate:
  - AC-012 through AC-014 pass, existing scenario behavior remains green, and performance review confirms batching, preloading, concurrency, and output bounds.
- Dependencies:
  - Phase 2 establishes release execution and explicit ownership; directive service extraction itself may start after the relevant scenario extension points are confirmed.
- Parallelizable Work:
  - `bulk_users` and `simulate_progress` can be implemented in parallel with shared agreement on reference generation, warning/result structures, and deterministic random-state handling.

## Phase 5: Deliver the review_demo Profile and Deployment Job Contract

- Goal: Create a retry-safe representative QA dataset and invoke it through the same CLI after migrations without coupling Torus readiness or persistence to Kubernetes.
- Requirements: FR-005, FR-006; AC-015, AC-016, AC-017, AC-018.
- Tasks:
  - [ ] Author the immutable bundled `review_demo` scenario with explicit author/institution establishment and stable synthetic references covering authoring, publication, product, section, enrollment, learner progress, gradebook, discussion, gating, and analytics states without embedded credentials.
  - [ ] Make profile operations reconciliation-aware so a Kubernetes retry converges on the intended state rather than silently duplicating projects, users, sections, enrollments, or learner results.
  - [ ] Add deployment configuration that omits the seed Job when `PREVIEW_QA_SEED_PROFILE` is absent and creates it only after successful migrations when present.
  - [ ] Pass the resolved profile as a discrete final argument to `bin/seed scenarios run --name <profile>` without shell interpolation; use `seed-<profile>-<release-id>`, application/environment/release/profile/component labels, `restartPolicy: Never`, `backoffLimit: 1`, and explicit CPU/memory requests and limits initially matching the migration Job.
  - [ ] Preserve Kubernetes ownership of stdout/stderr, exit observation, one retry, Job status, resource visibility, and the existing retention convention; add no Torus startup coordinator, Job API client, readiness dependency, or Job identity/history storage.
  - [ ] Audit Playwright's test-only controller, fixtures, token, and per-spec identifiers and leave their self-seeding lifecycle independent of `review_demo` and any startup-status endpoint.
- Testing Tasks:
  - [ ] Execute `review_demo` through the release dispatcher and assert every representative domain state plus absence of credentials in source and logs.
  - [ ] Execute the profile twice and verify reconciliation and stable references do not introduce unintended duplicates.
  - [ ] Add static or rendered-manifest tests for omission/presence, migration ordering, discrete arguments, name/labels, restart policy, retry limit, resources, logs/retention ownership, and lack of readiness coupling.
  - [ ] Run the existing Playwright scenario-fixture tests and add a contract check proving they reference neither `review_demo` nor a startup-status endpoint.
  - [ ] Add negative repository checks for an Oban seed job/queue, seed-run schema or migration, startup-status route, and persistent execution history.
  - Command(s): `mix test <review_demo and deployment-contract tests>`; `<existing Playwright fixture test command>`; `mix format`; rendered deployment-manifest validation in the owning repository.
- Definition of Done:
  - `review_demo` creates the approved synthetic state through `bin/seed`, converges under the configured retry, the post-migration Job meets the operational contract, and Playwright remains independently self-seeding.
- Gate:
  - AC-015 through AC-018 pass; deployment ownership and rollout evidence are identified; the Job does not affect application readiness.
- Dependencies:
  - Phases 2 and 4; Phase 1's preview image is required for end-to-end Job execution.
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
  - Phases 1 through 7.
- Parallelizable Work:
  - Review lenses and documentation verification may run concurrently after the implementation diff stabilizes; end-to-end manual QA begins only after all phase gates pass.

## Parallelization Notes

- Phase 1 is the critical-path foundation because all callable capabilities depend on its compile-time and runtime boundary.
- After Phase 1, Phase 2 CLI/scenario ownership and Phase 6 masquerade lifecycle are independent workstreams. Phase 3 can begin once Phase 2 fixes the common CLI result interface.
- Phase 4 directive work can overlap Phases 2 and 3, but its final release tests depend on Phase 2. Phase 5 depends on the completed CLI and new directives.
- Phase 7 UI and mailbox work can overlap Phases 2 through 5 but requires the effective-enablement contract from Phase 1 and masquerade state contract from Phase 6.
- Assign one owner to changes in shared scenario parser/validator/runtime files and one owner to shared router/session/layout files to avoid conflicting edits. Integrate each workstream only after its focused gate is green.
- Review and verification tasks should be performed continuously within phases; Phase 8 consolidates evidence rather than postponing security, performance, accessibility, or test work.

## Phase Gate Summary

- Gate A — Preview boundary: `MIX_ENV=preview` builds production-shaped, runtime QA activation is deny-by-default, production remains compile-time clean, and preview email is always local.
- Gate B — Scenario CLI: bundled listing and synchronous bundled/custom execution pass with strict usage, full DSL compatibility, explicit ownership, bounded output, and no application-managed seed state.
- Gate C — Project ingestion: bounded HTTP/HTTPS download, explicit author selection, existing ingest reuse, cleanup, redaction, and deterministic exits pass.
- Gate D — Scenario extensions: deterministic `bulk_users` and `simulate_progress` pass integration and performance checks and the separate Stagehand path is retired.
- Gate E — Deployment profile: `review_demo` is representative and retry-safe, the post-migration Job contract is validated, and Playwright remains independent.
- Gate F — Masquerade security: a masqueraded session is capability-equivalent to the target's direct session outside the two explicit exceptions, all general admin access is absent or denied, actor identity is usable only for audit, stop, and route-local mailbox authorization, and signed-session lifecycle, LTI clearing, and safe stop behavior pass adversarial tests.
- Gate G — UI and mailbox: required authenticated shells pass accessibility coverage and the runtime-enabled preview mailbox admits a current system administrator or the valid original admin actor during masquerade, without granting that session access to any other admin surface.
- Gate H — Release readiness: all FR/AC evidence, required reviews, formatting/tests, preview build, deployment validation, documentation, manual QA, and scope-exclusion checks pass.
