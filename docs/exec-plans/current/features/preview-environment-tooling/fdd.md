# Preview Environment Seeding and User Masquerade - Functional Design Document

## 1. Executive Summary

This design supports QA preview instances through three coordinated concerns. A production-shaped `MIX_ENV=preview` release compiles in CLI seeding and system-administrator masquerading, while runtime `DEV_QA_TOOLS_ENABLED` activation makes those tools and the protected mailbox available. Independently of runtime activation, every preview release routes email to a local non-delivering adapter.

Seeding is a synchronous release CLI intended only for operators with shell or IEx access. It lists bundled scenarios, runs a bundled scenario or local YAML file through the full `Oli.Scenarios` engine, and downloads and ingests a Torus project archive from an HTTP/HTTPS URL. The post-migration Kubernetes Job invokes this same CLI for `review_demo`.

Torus adds no seed web UI or API, Oban worker or queue, durable seed-run state, YAML snapshot storage, deployed-safe scenario allowlist, or application-managed retry system. Shell access is the seed authorization boundary and the external deployment-management system owns operator access/auditing. User masquerade remains an application feature because it is required for manual QA; it retains system-admin authorization, signed session state, dual-identity auditing, and the persistent warning/stop UI.

## 2. Requirements & Assumptions

- Functional requirements:
  - FR-001 through FR-003 define the preview-build/runtime-activation boundary, synchronous release commands, scenario listing/execution, and URL archive ingestion.
  - FR-004 through FR-006 add the Stagehand-derived directives, invoke `review_demo` from Kubernetes, and preserve Playwright-owned setup.
  - FR-007 through FR-009 retain secure, auditable, accessible user masquerade.
  - FR-010 replaces outbound email delivery with a local non-delivering adapter and provides an authenticated mailbox in QA mode.
- Non-functional requirements:
  - CLI commands return bounded output and deterministic exit codes and never print complete YAML, credentials, learner responses, or archive contents.
  - Kubernetes owns startup retry, status, and resource limits. Scenario handlers own their existing transaction boundaries; partial changes are not rolled back.
  - Masquerade authorization fails closed independently at route/event, service, session-restoration, and stop boundaries.
- Assumptions:
  - Shell or IEx access is already privileged enough to execute arbitrary application code and mutate the database.
  - The deployment-management interface controls and audits shell access outside Torus.
  - Seed inputs contain synthetic QA data. Operators retain input files externally when durable reproducibility is required.
  - Reachable URLs identify compatible Torus project export archives.
  - Preview instances use fresh databases or explicitly sanitized non-production copies and receive no production integration credentials; this feature does not make unsanitized production clones safe.

## 3. Repository Context Summary

- What we know:
  - `Oli.Scenarios` already parses and synchronously executes YAML, including `use`, assertions, and hooks.
  - `Oli.Scenarios.RuntimeOpts` currently selects the first existing author/institution and the engine otherwise creates defaults; deployed CLI scenario execution needs an explicit-ownership mode.
  - `Oli.Utils.Stagehand` contains bulk enrollment and learner simulation behavior to move behind scenario directives.
  - `Oli.Interop.Ingest.ingest/2` is the existing non-interactive project archive ingestion boundary.
  - `rel/overlays/bin/migrate` demonstrates the repository's release-command wrapper pattern.
  - Playwright already owns per-spec YAML setup through its test-only controller and fixtures.
  - Existing system-admin routes, auth/session restoration, root layouts, and `Oli.Auditing` provide the masquerade integration points.
- Unknowns to confirm:
  - None. Command syntax, deployment Job behavior, layout coverage, and contained external integrations are defined below; implementation waypointing must confirm the exact code targets.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

Preview images are production-shaped releases built with `MIX_ENV=preview`. `config/preview.exs` is standalone and imports neither `prod.exs` nor `dev.exs`. It initially copies only the applicable production settings, sets the preview build marker, and configures `Swoosh.Adapters.Local`. `config/runtime.exs` treats `DEV_QA_TOOLS_ENABLED` as runtime activation: any casing of `true` enables it, while missing, blank, whitespace-padded, false, and malformed values disable it. `Oli.DevQATools.Config.enabled?/0` requires both the compile-time preview marker and runtime activation. Compile-shaped release and router integrations use `Application.compile_env/3`; callable boundaries recheck runtime state (AC-001 through AC-004).

The Dockerfile accepts `ARG MIX_ENV=prod`, propagates it through dependency selection, compilation, release construction, smoke execution, and final-stage copy paths, and therefore remains production-safe when callers omit the argument. Both automatic and manual preview-image jobs pass `MIX_ENV=preview`; production workflows retain `prod`. The implementation audit classifies existing `Mix.env()` branches and dependency `only:` selectors, including `start_permanent`, endpoint static gzip, and compiler paths/options, so preview receives production-like behavior where required (AC-004).

CI responsibilities remain proportional to the existing pipeline: ordinary PR checks compile/test under `MIX_ENV=test`, the preview-image workflow builds the full `MIX_ENV=preview` release on PRs, and the existing package/release workflow validates `MIX_ENV=prod` after merge. This work adds no production compile gate or automated configuration-parity audit to PR CI. `guides/process/building.md` becomes the discoverable source for the purpose of each Mix environment, the workflow that builds it, the standalone configuration contract, compile-time versus runtime configuration, and the runtime activation flag. Earlier production validation is a future operational response only if package-stage failures become recurrent.

`Oli.Release.DevQATools` is a thin synchronous command dispatcher exposed through the `bin/seed` release overlay script. It supports three operations:

- `bin/seed scenarios list` lists immutable bundled scenario metadata;
- `bin/seed scenarios run --name <id>` or `--file <path>` runs a bundled scenario or operator-provided local YAML through `Oli.Scenarios`;
- `bin/seed projects ingest --url <http(s)-url> --author <selector>` downloads and ingests a project archive for an explicitly selected author through `Oli.Interop.Ingest`.

It prints a bounded human-readable summary, returns zero only on success, and maps usage, disabled, download, parse, scenario, assertion, hook, and ingest failures to nonzero exits (AC-005 through AC-011). `--name` and `--file` are mutually exclusive; unknown options, missing values, and extra positional arguments print usage and fail. It does not accept an inline Elixir expression as input; operators who need arbitrary code already have IEx access. The underlying functions remain directly callable from IEx.

Bundled scenarios live beneath an application-owned release directory with stable identifier, description, and version/digest metadata. Listing never parses or executes scenario bodies. A path supplied to `run` is intentionally not restricted to that directory because shell access is trusted.

CLI scenarios use the complete existing scenario DSL without an additional deployed-safe policy. The execution adapter disables implicit owner selection and creation. YAML must establish current author and institution before dependent mutation by creating/selecting scenario references, using restricted unique lookups, or selecting explicit configured defaults such as `default_admin`. Missing, late, ambiguous, inactive, or wrong-type ownership fails before dependent mutation (AC-007 through AC-009).

`Oli.Release.DevQATools.ProjectIngest` accepts only HTTP/HTTPS URLs, uses the application's HTTP client with finite connect/receive timeouts, bounded redirects, and a configured maximum archive size, streams into a uniquely created temporary directory, calls `Oli.Interop.Ingest.ingest/2`, and cleans up in `after`. It never logs URL credentials, response bodies, or archive contents (AC-010 and AC-011). Because the operator has shell access, network policy—not an application SSRF allowlist—is the authoritative reachability boundary.

`bulk_users` and `simulate_progress` become normal `Oli.Scenarios` directives. Scenario-owned services replace Stagehand's reusable behavior. They produce stable references, support optional deterministic random seeds, use collision-safe synthetic identities, bound internal concurrency, and return structured warnings for unsupported content (AC-012 through AC-014).

The bundled `review_demo` scenario creates the approved representative QA dataset without embedded credentials. A post-migration Kubernetes Job runs it synchronously through the release CLI. No Torus process creates or monitors the Job (AC-015 through AC-017).

`Oli.DevQATools.Masquerade` owns start, stop, restore, expiry, and invalidation. The existing tamper-protected signed session holds only the actor identifier, target identifier, issued/expiry timestamps, and a random reference; this work does not change application-wide session encryption. Ordinary authorization sees only the target; actor identity is available only to auditing, the stop operation, and route-local `/dev/mailbox` authorization. Chaining is rejected and invalid state is cleared (AC-019 through AC-022).

`OliWeb.Components.MasqueradeBanner` renders from `default`, `workspace`, `delivery`, `delivery_student_dashboard`, `delivery_dashboard`, authenticated LiveView, and authenticated `chromeless` surfaces. It names the target, uses text plus high-contrast magenta treatment, and exposes a CSRF-protected stop action with keyboard and screen-reader support (AC-023 and AC-024). `delivery_from_payment` is excluded because its Cashnet callback pipeline does not restore a current user. `lti` is excluded because LTI establishes a fresh external identity; entering LTI login/launch clears or rejects an active masquerade before rendering.

Every preview release uses `Swoosh.Adapters.Local`, even when interactive QA tooling is runtime-disabled, so a misconfigured preview deployment cannot deliver email externally. A preview-compiled `/dev/mailbox` forward to `Plug.Swoosh.MailboxPreview` sits behind `:browser`, runtime-enable checks, and a dedicated authorization plug that accepts either the current system administrator or the original system-administrator actor of a valid active masquerade. The plug does not replace the target `current_user`, and no other admin route accepts actor identity. Disabled, unauthenticated, non-admin-originated, expired, invalid, and forged requests are non-disclosing. The existing unauthenticated dev/test mailbox declaration is consolidated into this protected route so the mailbox has one access policy (AC-025 and AC-026).

No preview-specific branches are added to LTI grade passback, Stripe, Cashnet, webhooks, analytics destinations, or other external integrations. Fresh or explicitly sanitized databases and non-production runtime credentials are the operational boundary for those effects. An unsanitized production clone is unsupported; making one safe would require a separate, comprehensive design rather than a partial integration allowlist.

### 4.2 State & Data Flow

Scenario command flow:

1. The release wrapper passes parsed arguments to `Oli.Release.DevQATools`.
2. The dispatcher verifies effective enablement and resolves a bundled identifier or local path.
3. The adapter parses the YAML and validates explicit ownership ordering without applying a broader directive allowlist.
4. `Oli.Scenarios` executes synchronously using its existing transaction semantics.
5. The command emits a bounded summary and exits zero or nonzero. No run record or background job is created.

Project ingest flow:

1. The command validates scheme, author selector, and effective enablement.
2. It streams the response to a unique temporary file with bounded redirects, time, and bytes.
3. It invokes `Oli.Interop.Ingest.ingest/2`, reports the created project identity, and removes temporary data after success or failure.

Kubernetes flow:

1. Deployment automation waits for successful migrations and omits the seed Job when `DEV_QA_SEED_PROFILE` is absent.
2. It creates `seed-<profile>-<release-id>` with application, environment, release, profile, and `component=dev-qa-seed` labels, resolves the configured profile, and passes it as the final argument to `bin/seed scenarios run --name <profile>` without shell interpolation.
3. The Job uses `restartPolicy: Never`, `backoffLimit: 1`, and explicit CPU/memory requests and limits initially matching the migration Job.
4. Kubernetes uses process exit for success/failure and owns retry, stdout/stderr logs, status, resource enforcement, and its existing Job-retention/TTL convention. Torus receives or persists no Job identity.

Masquerade flow:

1. An enabled current system administrator starts masquerade from user detail.
2. The service validates an active delivery target, audits actor/target, renews the session, and stores signed state.
3. Each request revalidates flag, expiry, actor, and target before installing the target as `current_user`.
4. Stop, logout, expiry, target invalidation, runtime disablement, or entry into a new LTI login/launch identity flow clears or rejects state and redirects safely.

### 4.3 Lifecycle & Ownership

- Operators own seed invocation, input retention, and interpretation of partial failures.
- Bundled scenario files are immutable release assets; custom YAML and downloaded archives exist only in operator storage or bounded process-local temporary storage.
- Kubernetes owns startup execution lifecycle. Torus owns only the synchronous process result.
- Scenario-created domain records remain in their canonical tables; there is no separate seed ownership or run-history model.
- Signed session storage owns active masquerade state. Audit storage owns masquerade lifecycle records.

### 4.4 Alternatives Considered

- Admin workbench plus Oban and run persistence: rejected because shell access is acceptable and already privileged; the application layers add substantial UI, authorization, storage, and orchestration scope.
- Deployed-safe directive allowlist: rejected for CLI execution because an operator with shell/IEx access can already invoke arbitrary application behavior. Existing scenario validation remains useful, but is not a security sandbox.
- Store exact YAML for audit: rejected in the reduced scope because Torus stores no seed runs. The deployment-management platform audits shell access and operators retain inputs externally.
- Application startup or Oban seeding: rejected because a post-migration Kubernetes Job cleanly owns deployment-time execution.
- Remove masquerade with the workbench: rejected because manual QA still requires efficient identity switching and this cannot be replaced by shell execution.
- Keep `MIX_ENV=prod` and use `DEV_QA_TOOLS_ENABLED` at compilation and runtime: superseded because it overloads a single variable as build identity and operator activation while scattering a coherent preview safety profile through production configuration. A dedicated environment is selected with a one-time review of production-like branches and clear build documentation.
- Base preview on `dev.exs`: rejected because code reloading, development dependencies, relaxed runtime behavior, and developer conveniences do not represent a production-shaped Kubernetes release.
- Import `prod.exs` from `preview.exs` or extract a shared `release.exs`: rejected because the current production file has too little reusable configuration to justify implicit inheritance or another abstraction layer. Preview instead owns a small, deliberate copy that can be extracted later if meaningful duplication emerges.
- Disable LTI grade passback, Stripe, and Cashnet specifically in preview: rejected because fresh preview databases do not configure them and selectively suppressing three integrations would not safely contain the broader effects of an unsanitized production clone.

## 5. Interfaces

- Build/runtime configuration:
  - Preview images use `MIX_ENV=preview`; production images default to `MIX_ENV=prod`.
  - `config/preview.exs` is standalone, imports neither environment file, and explicitly declares the applicable production-shaped settings plus preview capabilities and safety overrides.
  - `DEV_QA_TOOLS_ENABLED`: case-insensitive `true` required at runtime to activate seeding, masquerade, and mailbox access; it is not a build argument.
  - `DEV_QA_SEED_PROFILE`: optional bundled identifier used by deployment automation; it does not enable anything.
  - `guides/process/building.md`: documents the `test`, `prod`, and `preview` build paths, configuration ownership, compile/runtime boundary, and preview activation procedure.
- Release interface:
  - `bin/seed scenarios list`: list bundled identifiers, descriptions, and versions/digests.
  - `bin/seed scenarios run --name <id>`: synchronously execute bundled YAML.
  - `bin/seed scenarios run --file <path>`: synchronously execute custom YAML.
  - `bin/seed projects ingest --url <http(s)-url> --author default_admin|email:<email>`: synchronously import a Torus archive.
- Scenario ownership interface:
  - Explicit create/reference, restricted unique lookup, and configured-default selectors establish `current_author` and `current_institution`.
- Kubernetes interface:
  - After migrations succeed, an optional Job uses the Torus image and passes the resolved profile to `bin/seed scenarios run --name <profile>` as a discrete argument.
  - The Job uses `restartPolicy: Never`, `backoffLimit: 1`, resources initially matching the migration Job, the name `seed-<profile>-<release-id>`, and application/environment/release/profile/component labels.
  - Kubernetes owns logs and its existing retention policy; Torus persists no Job identity or result.
- Web interface:
  - Only masquerade start/stop and the persistent banner are added. There is no seed route, LiveView, controller, or API.
  - `/dev/mailbox` forwards to `Plug.Swoosh.MailboxPreview` only in preview-compiled/runtime-enabled images and only through current system-admin authentication or the original system-administrator actor of a valid active masquerade.
- External-effect interface:
  - `Oli.Mailer` uses `Swoosh.Adapters.Local` for every `MIX_ENV=preview` release, independent of runtime QA-tool activation.
  - No preview-specific behavior is added to other external-integration interfaces.
- Existing Playwright interface:
  - The test-only scenario endpoint, token, fixtures, and per-run identifiers remain unchanged (AC-018).

## 6. Data Model & Storage

- No seed-run, seed-claim, custom-definition, YAML-snapshot, or active-masquerade table is added.
- Scenario and ingest outputs use existing project, resource, publication, product, section, user, enrollment, attempt, and analytics tables.
- Custom YAML is read from the provided path and not copied into Torus storage. Project archives use bounded temporary filesystem storage and are deleted after execution.
- Existing audit storage receives masquerade lifecycle events only.
- Swoosh local mailbox messages use the adapter's in-memory development storage and are not a durable audit record.

## 7. Consistency & Transactions

- Scenario directives and `Oli.Interop.Ingest` retain their existing transaction boundaries.
- A failed scenario may leave earlier mutations committed; the CLI explicitly reports `partial_mutations_possible` when execution started.
- `review_demo` must use stable identities/references and reconciliation-aware operations so bounded Kubernetes retries do not silently duplicate its intended dataset.
- Masquerade session renewal and clearing are atomic with the HTTP response; required audit failures follow existing security-audit fail-closed conventions.

## 8. Caching Strategy

- No new cache is introduced. Bundled metadata may be read from release files per invocation because CLI frequency is low.
- PostgreSQL remains authoritative for scenario, ingestion, target validity, and masquerade authorization state.

## 9. Performance & Scalability Posture

- Commands run outside web request and Oban processes and do not consume application job queues.
- URL downloads stream to disk and enforce bounded time, redirects, and bytes.
- `simulate_progress` uses fixed-size batches with modest supervised concurrency and bounded per-task timeouts; shared section inputs are preloaded to avoid N+1 queries.
- Kubernetes declares CPU/memory requests and limits. No seed-specific global execution timeout is added inside Torus.

## 10. Failure Modes & Resilience

- Non-preview build: release commands and masquerade integrations are unavailable; runtime configuration cannot add them.
- Preview build but runtime-disabled: commands fail before mutation, masquerade fails closed, mailbox access is unavailable, and startup emits one instructional warning. Preview email containment remains active.
- Unknown scenario or invalid path/YAML: print a bounded error and exit nonzero.
- Ownership missing or invalid: reject before the first ownership-dependent directive; do not use implicit defaults.
- Scenario/assertion/hook failure: exit nonzero and report possible partial mutation without rollback.
- URL, redirect, timeout, size, archive, author, or ingest failure: exit nonzero, redact sensitive data, and clean temporary files.
- Kubernetes interruption: Kubernetes permits one retry through `backoffLimit: 1`; `review_demo` reconciliation limits duplication.
- Invalid/expired masquerade state or entry into a new LTI login/launch flow: clear or reject it, audit the reason, and continue as the actor when safe or signed out otherwise.
- Mailbox access while disabled or without current system-admin authorization: return a non-disclosing response and expose no message metadata.
- Unsanitized production database clone or production credentials: unsupported deployment configuration; the feature provides no claim of broad external-effect containment beyond application email.

## 11. Observability

- CLI stdout/stderr contains operation, source type, bundled identifier or digest where available, duration, aggregate counts, result code, and partial-mutation warning. It excludes complete YAML, archive bodies, URL credentials, learner responses, and secrets.
- Process exit is the authoritative command result. Kubernetes collects logs and owns Job status, retries, duration, and resource monitoring.
- Application startup emits one warning only for preview-compiled/runtime-disabled state and an enabled signal when the preview environment and runtime flag are both active.
- Audit masquerade start, stop, expiry, and invalidation with actor, target, timestamp, session reference, and bounded request context.
- Local mailbox inspection relies on authenticated access logs; email contents are visible only inside the protected mailbox UI and excluded from application telemetry.

## 12. Security & Privacy

- The preview build/runtime activation boundary protects both capabilities. CLI seed authorization relies on existing deployment shell/IEx controls; Torus adds no redundant role model for shell callers.
- The release command is powerful by design and is not a sandbox. Documentation warns that arbitrary custom scenarios and hooks execute trusted application behavior and mutate real data.
- URL ingestion accepts only HTTP/HTTPS, bounds resource usage, redacts credentials, and relies on deployment network policy for destination control.
- YAML ownership is explicit and no first-record/generated-default fallback is allowed in CLI mode.
- Masquerade independently requires a current system administrator, prohibits chaining, separates actor from target authorization, renews sessions, and expires state. Actor authorization is limited to two narrowly scoped boundaries: stop and `/dev/mailbox`; every other capability is authorized solely as the target.
- The preview environment forces `Swoosh.Adapters.Local`; runtime enablement additionally exposes the system-admin-protected mailbox. Other external integrations and custom hook effects remain outside this feature's containment boundary and require fresh or explicitly sanitized data plus non-production credentials.

## 13. Testing Strategy

- Configuration tests cover the Mix-environment/runtime-flag matrix, casing variants, disabled values, warning behavior, production-safe Docker defaults, preview build arguments, and the required existing production-like branch classifications (AC-001 through AC-004). The preview-image workflow supplies the preview release build check; existing production packaging remains unchanged.
- Release command tests cover listing, bundled and custom execution, full DSL compatibility, explicit ownership, bounded output, exit codes, and absence of application authorization/run persistence (AC-005 through AC-009).
- Ingest tests use a controlled HTTP server for scheme validation, redirects, timeout, byte limits, credential redaction, cleanup, author selection, and successful/failed `Oli.Interop.Ingest` calls (AC-010 and AC-011).
- Scenario tests cover `bulk_users`, `simulate_progress`, deterministic seeds, stable identities, collision handling, supported/unsupported content, bounded concurrency, and Stagehand migration (AC-012 through AC-014).
- Kubernetes/profile tests execute `review_demo` through the release dispatcher, verify representative state and retry reconciliation, and inspect Job configuration. Static checks prove no Oban seeding, run schema, or status endpoint exists (AC-015 through AC-017).
- Playwright compatibility tests preserve existing fixture behavior (AC-018).
- Masquerade tests cover authorization, chaining, expiry, logout, target invalidation, runtime disablement, actor/target separation, audit attribution, persistent target mutations, safe redirects, keyboard operation, accessible names, and non-color cues (AC-019 through AC-024). The layout matrix includes `default`, `workspace`, `delivery`, `delivery_student_dashboard`, `delivery_dashboard`, authenticated LiveView, and authenticated `chromeless`; it excludes `delivery_from_payment` and `lti` and verifies LTI entry clears or rejects masquerade.
- Mail containment tests verify the preview adapter override regardless of runtime flag, absence of external delivery, preview/runtime route gating, mailbox access for a current system administrator and for a valid original admin actor during masquerade, continued target identity within that mailbox request, denial of adjacent admin routes, and denial to anonymous, lesser-role, expired, invalid, or forged states (AC-025 and AC-026).
- A scope guard confirms no preview-specific LTI grade-passback, Stripe, Cashnet, or broad production-clone safety behavior is introduced.
- Required gates are targeted `mix test`, `mix format`, the existing preview-image release build, build-documentation review, and security/performance/Elixir/UI/requirements reviews. No additional `MIX_ENV=prod` PR gate is added.

Acceptance-criterion traceability clarifications:

- AC-002 and AC-003 are verified by negative enablement and startup log-capture tests.
- AC-006 and AC-008 are verified by release-dispatch and explicit-ownership integration tests.
- AC-013 is verified by deterministic `simulate_progress` scenario tests.
- AC-016 is verified by the `review_demo` end-to-end scenario test.
- AC-020 and AC-021 are verified by masquerade lifecycle and actor/target authorization tests.

## 14. Backwards Compatibility

- Existing `Oli.Scenarios` and Playwright execution remain available. Explicit ownership is enforced only by the new release adapter.
- New directives extend the DSL without changing existing syntax.
- Stagehand call sites migrate before its standalone API is removed or reduced to temporary local wrappers.
- No database migration is introduced for seed tooling.
- Non-masqueraded sessions and existing authorization behavior remain unchanged.

## 15. Risks & Mitigations

- CLI power is mistaken for sandboxed input: document shell-equivalent trust explicitly and compile the capability only under `MIX_ENV=preview`.
- Preview configuration becomes misunderstood or stale: keep it small, document intentional duplication and every environment's build path in `guides/process/building.md`, review existing `Mix.env()` branches and dependency selectors when introducing preview, and rely on the preview-image and existing production-package builds for their respective environments. Extract shared configuration only if meaningful duplication emerges.
- Project download consumes resources or reaches an unintended destination: bound time/redirects/bytes, rely on deployment network policy, and clean temporary files.
- Scenario or retry creates partial/duplicate data: report partial mutation, use deterministic profile references, and make `review_demo` reconciliation-aware.
- External effects escape through an unsanitized clone or production credentials: explicitly support only fresh or sanitized databases and non-production runtime configuration. Email is contained; broad safe-clone operation requires a separate inventory and design.
- Custom hooks cause external effects: retain shell-equivalent trust and document that only email sent through `Oli.Mailer` is contained by this feature.
- Masquerade leaks actor privilege: preserve strict actor/target separation and test representative authorization paths.
- Banner misses a shell: maintain an authenticated-root-layout coverage inventory.

## 16. Open Questions & Follow-ups

None.

## 17. References

- `docs/exec-plans/current/features/preview-environment-tooling/prd.md`
- `docs/exec-plans/current/features/preview-environment-tooling/requirements.yml`
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
- `guides/process/building.md`
- `docs/design-docs/scoped_feature_flags.md`
- `lib/oli/scenarios.ex`
- `lib/oli/scenarios/runtime_opts.ex`
- `lib/oli/utils/stagehand.ex`
- `lib/oli/interop/ingest.ex`
- `lib/oli_web/router.ex`
- `rel/overlays/bin/migrate`

## Decision Log

### 2026-09-09 - Preserve mailbox access during administrator masquerade
- Question: May the original administrator inspect `/dev/mailbox` while masquerading as a non-admin user?
- Decision: Yes. Stop and `/dev/mailbox` are the only actor-authorized operations during masquerade; every other authorization decision uses only the target identity.
- Rationale: Mail inspection is part of the preview QA workflow and should not require ending the user session being tested.
- Impact: Add a dedicated route-local mailbox authorization plug that validates the original actor without replacing `current_user`, plus parity tests proving all adjacent administrator capabilities remain denied.

### 2026-09-09 - Adopt a standalone `MIX_ENV=preview` release
- Question: Should preview deployments use a dedicated Mix environment and `config/preview.exs`?
- Decision: Yes. Build preview images with `MIX_ENV=preview`, use a standalone `config/preview.exs` that imports neither `prod.exs` nor `dev.exs`, and use `DEV_QA_TOOLS_ENABLED` only for runtime activation.
- Rationale: Preview has a coherent build-level safety and capability profile, while the small amount of reusable production configuration does not justify inheritance or a shared base layer. Explicit ownership, a one-time branch/dependency review, and discoverable build documentation preserve the intended production-shaped behavior.
- Impact: Add standalone `config/preview.exs`; parameterize Docker release paths with a safe `prod` default; pass `MIX_ENV=preview` from both preview-image jobs; intentionally copy applicable settings; treat `:preview` as production-like for permanent startup, gzip, compiler behavior, and applicable dependency selectors; document all environment build paths in `guides/process/building.md`. No new production PR build gate or drift audit is added.

### 2026-09-09 - Contain email and exclude broad production-clone safety
- Question: Which external effects must this preview-tooling feature contain?
- Decision: Every preview release overrides outbound email with `Swoosh.Adapters.Local`; `Plug.Swoosh.MailboxPreview` is exposed at `/dev/mailbox` only to current system administrators, including the original admin actor during a valid active masquerade, while runtime QA tools are enabled. Do not add preview-specific suppression for LTI grade passback, Stripe, Cashnet, or other integrations.
- Rationale: Email is routinely triggered by QA flows. Fresh preview databases do not configure the other integrations, and suppressing only a few effects would create a misleading claim that unsanitized production clones are safe.
- Impact: Consolidate the existing dev/test mailbox under the protected route and configure preview mail delivery at build time. Require fresh or explicitly sanitized databases and non-production credentials; handle production-clone safety as a separate future design.

### 2026-09-09 - Define masquerade layout coverage and LTI behavior
- Question: Must `default`, `delivery_from_payment`, and `lti` render the masquerade banner?
- Decision: Include `default`; exclude `delivery_from_payment` and `lti`. Entering a new LTI login/launch flow clears or rejects active masquerade. Required coverage also includes `workspace`, `delivery`, `delivery_student_dashboard`, `delivery_dashboard`, authenticated LiveView, and authenticated `chromeless` surfaces.
- Rationale: General browser pages use `default` and can retain masquerade. Cashnet callbacks do not restore a current user. LTI establishes a new external identity and must not combine it with an existing masquerade.
- Impact: Add an explicit layout test matrix and LTI-boundary lifecycle tests; do not add banner rendering to the Cashnet callback or LTI layouts.

### 2026-09-09 - Define the deployment seed Job contract
- Question: What Kubernetes ordering, retry, resources, identity, logging, and retention conventions should startup seeding use?
- Decision: Create the Job only after successful migrations and only when a profile is present. Pass the resolved profile as a discrete argument to `bin/seed scenarios run --name <profile>` using `restartPolicy: Never`, `backoffLimit: 1`, explicit resources initially matching migrations, and the labeled name `seed-<profile>-<release-id>`.
- Rationale: This supplies deterministic ordering, one bounded retry, and useful operational identity while leaving orchestration entirely outside Torus.
- Impact: Kubernetes owns stdout/stderr, process exit, status, resources, and existing Job retention. Torus persists no Kubernetes identity or seed result.

### 2026-09-09 - Name the release seeding interface `bin/seed`
- Question: What release command should expose scenario and project seeding operations?
- Decision: Use a dedicated `bin/seed` release-overlay executable with `scenarios list`, `scenarios run --name|--file`, and `projects ingest --url --author` subcommands. The wrapper delegates to the generated release's supported `bin/oli eval` facility.
- Rationale: This provides clear shell and Kubernetes syntax without modifying generated `bin/oli`, and matches the repository's existing `bin/migrate` overlay pattern.
- Impact: A small Elixir argument parser rejects ambiguous or malformed invocations with usage text and nonzero exit; the same functions remain callable directly from IEx.

### 2026-09-09 - Reduce seeding to a privileged release CLI
- Question: Should Torus provide an in-application seed-management system?
- Decision: Remove the admin workbench, Oban seed scheduling, seed persistence, YAML audit snapshots, deployed-safe allowlist, and seed HTTP/status APIs. Provide synchronous release operations to list scenarios, run bundled/custom YAML, and ingest project URLs; Kubernetes invokes the same interface.
- Rationale: Shell access is already equivalent to privileged application execution. Following established CLI-based seeding practice sharply reduces redundant authorization, UI, orchestration, persistence, and operational complexity.
- Impact: Seed status and retries belong to the invoking shell or Kubernetes. Torus stores only resulting domain records and emits bounded command output.

### 2026-09-09 - Retain user masquerade for manual QA
- Question: Should masquerade be removed with the admin seed workbench?
- Decision: Keep system-administrator masquerade.
- Rationale: Manual QA still requires efficient inspection of seeded learner and instructor experiences.
- Impact: Session security, system-admin authorization, actor/target auditing, accessible warning UI, and stop behavior remain in scope.

### 2026-09-09 - Require YAML-defined execution ownership
- Question: How should CLI scenario execution resolve its author and institution?
- Decision: YAML must create/select scenario references, use restricted unique lookup, or select explicit configured defaults. CLI execution prohibits implicit first-record and generated-default ownership.
- Rationale: Explicit YAML remains self-describing even though Torus no longer persists run history.
- Impact: The release adapter adds ownership selection and ordering validation without constraining the rest of the scenario DSL.

### 2026-09-09 - Separate preview compilation from runtime activation
- Decision: `MIX_ENV=preview` controls compile-time inclusion. `DEV_QA_TOOLS_ENABLED` must equal `true`, case-insensitively, only at runtime. Preview-built but runtime-disabled images emit one instructional warning.
- Rationale: Compile exclusion and deliberate runtime opt-in remain, but each control now has one meaning.
- Impact: Requires preview configuration, Docker environment selection, runtime-only flag handling, conditional integrations, warning behavior, and environment/flag matrix tests.

### 2026-09-09 - Use Kubernetes for startup seeding and preserve Playwright setup
- Decision: Run `review_demo` through a post-migration Kubernetes Job and leave Playwright's per-spec scenario setup unchanged.
- Rationale: Kubernetes owns deployment execution, while Playwright already owns isolated automation data.
- Impact: No application startup coordinator or shared Playwright seed profile is added.
