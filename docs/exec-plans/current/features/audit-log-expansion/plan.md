# Audit Log Expansion - Delivery Plan

## Scope

Owner-approved packaging direction, updated 2026-10-29: **seven implementation PRs**, including **exactly four coverage PRs as the planning target**. Keep each coverage group together during planning and implementation. Only if actual execution shows that one PR is too large will the owner and engineer consider dividing it; no proactive split, extra pilot, extra child or new PR is implied by estimates or internal work areas.

Jira MER-6066 was read in full on 2026-10-29 (no comments returned). Code evidence refers to `237980b77c`. This is documentation, not a claim of implemented features, executed tests, production measurements or approved publication.

Reference artifacts:

- `docs/exec-plans/current/features/audit-log-expansion/prd.md`
- `docs/exec-plans/current/features/audit-log-expansion/fdd.md`
- `docs/exec-plans/current/features/audit-log-expansion/requirements.yml`
- `docs/exec-plans/current/features/audit-log-expansion/coverage-inventory.md`
- `docs/exec-plans/current/features/audit-log-expansion/caller-inventory.tsv`
- `docs/exec-plans/current/features/audit-log-expansion/jira-subtasks.md`

All implementation PRs target `story/MER-6066-audit-log-expansion`; the completed integration targets `master`. Reuse `MER-6066-audit-log-expansion` and the existing worktree for the first slice. Later branch/worktree actions require the personal workflow's concrete confirmation; do not rename existing resources for hypothetical child keys. One proposed Jira Sub-task corresponds to each implementation PR. Combined acceptance remains on MER-6066, not an extra child.

## Clarifications & Default Assumptions

- PR-01 includes full contracts/insert tests, partitioning, existing central-history migration and same-PR/same-deployment retirement with safe rollback. It is large; internal review checkpoints do not create extra PRs.
- PR-02 includes Boundary, CI and one real mutation pilot. User deletion is the proposed focused action. This is the only separately planned implementation pilot.
- PR-03 through PR-06 are the four coverage PRs. PR-05 includes assessment settings and conversion/retirement of settings_changes. There is no separate settings-history PR.
- Oban plus central history is the base for asynchronous work; no generic audit_operations table. Establish safeguards inside the first actual async workflow, and reuse them. ClickHouse belongs to PR-06 with no dedicated pilot/PR. Terminal capture versus pruning remains a required verification gate, not an assumed capability.
- PR-07 completes UI/search. PR-01 retains basic existing reader compatibility throughout integration.
- Six-month UTC partitions, exact Boundary topology, proposed performance budgets, target privileges and maintenance/rollback capacity still require the technical evidence described in the FDD. Approval of packaging does not imply these experiments passed.
- New writes use strict v2 contracts; migrated incomplete history uses v1. Any integration-only compatibility adapter has a removal/compliance gate before release; no permanent dual history or fabricated actor.
- Every supported UI/API/MCP/bulk/job/Scenario path must be covered. Do not invent endpoints for unsupported channels or audit routine learning merely because it writes rows.
- Internal work areas in the inventory organize implementation and review. They are neither independently merged phases nor a hidden backlog of additional PRs/subtasks.

## Sizing and dependencies

The four coverage PRs are expected to be medium/large and may differ in size. Organize their reviews by internal domain blocks and run tests as those blocks are implemented. Do not translate lexical reference counts into a claim of equal effort or a calendar estimate. Do not split prospectively. If actual implementation becomes unreviewable, present the concrete diff/scope and a proposed division for owner agreement at that time.

Use the sequence below to avoid shared-context merge conflicts. Cross-domain composition uses existing code until its owning block is migrated; a migrated field must never retain an unaudited generic-update shortcut. PR-03 establishes account/integration policies used by PR-04/05; PR-04 establishes authoring and first async policies used by PR-05/06. Section-specific integrations can be instrumented in PR-03 using existing section APIs; this does not require PR-05 first. DOT project/content policy is covered in PR-04 and its delivery settings in PR-05. Discussion/notes configuration is PR-05; moderation is PR-06. Remaining preferences stay late in PR-06.

## Common slice contract

Every domain PR below inherits these tasks and gates; they are not deferred to final QA:

1. Complete a per-action/per-field caller matrix from the inventory: UI, API, MCP, bulk, worker, Scenario, internal composition, direct `Repo` writes and dynamic invocation. Assign every hit to migrated, internal/composed, or excluded with a reason and test reference. An empty lexical search is not evidence of absence.
2. Close generic-update bypasses. For example, protecting `lock_user` is insufficient if unaudited `update_user` can still change the lock field. Move the raw write under the boundary and route protected attributes through an actor-aware command; restrict transitional APIs to explicitly unmigrated/derived fields, rejecting protected fields without trusted context. Mixed maps must compose the proper policies. If that cannot preserve behavior safely, pull the coupled callers into the same PR; only if execution demonstrates excessive size, discuss a split with the owner. Boundary alone cannot enforce field-level rules.
3. Keep persisted before-state, raw mutation and required event writes in the correct transaction. Preserve each action's existing authorization where it already lives; coordinators add no new permission checks. Preserve locks, result shapes and post-commit cache/broadcast behavior. Define no-op, nested/bulk cardinality and safe errors per command. Synchronous commands rely on the transaction and target row locks to avoid duplicate evidence and need no replay protocol. For async work, establish the replay protocol inside the first actual async coverage workflow (PR-04) and reuse it thereafter; classify partial/unknown outcomes truthfully. No separate pilot PR is planned.
4. Keep event-specific allowlists, deleted identities and actor-versus-subject assertions. Remove superseded manual captures in the same slice. Existing tests remain; adapt public behavior tests to audited operations, while narrowly scoped internal tests may exercise raw mutations. Factories remain suitable for unrelated fixtures and contract inserts.
5. Migrate each affected Scenario directive in its owning domain PR. Use the build_scenario skill for actual scenario authoring and extend_scenario only if required capability is missing. Setup PW is the explicit bootstrap actor; publishing/section/enrollment use the represented author/instructor. Do not create a global Scenario bypass. Changes to shared test support/configuration require the full clean-output suite.
6. Add meaningful success/failure/authorization/no-op/audit-failure rollback and duplicate/retry tests at application and supported transport boundaries, not just mocks of `capture`. Record tested revision and commands. Force Boundary checks, format, and run targeted tests before broader risk-driven checks. Full integration QA remains additive.
7. Follow repository review policy before merge: security/performance reviews always, Elixir for backend, UI where relevant, requirements when PRD changes. Dedicated reviewer orchestration is governed by `docs/CODEREVIEW.md`; no formal implementation review has been performed during planning.
8. Merge only after developer review and required CI into integration using a merge commit. Keep source/field inventory and actual proof references current. `verified_plan` records planned coverage, not implementation proof or owner acceptance; `proofs` stay empty until evidence exists.

### Command safety and verification conventions

All Mix commands require scoped escalated permissions on the first attempt under AGENTS.md. The repository's `mix test` alias drops, creates and migrates its target database: verify an explicitly isolated test database and environment/URL precedence before using any test command below. These are planned commands, not commands executed during planning. Never reset/migrate the shared development database.

- Per slice: `mix format --check-formatted`; `mix compile --warnings-as-errors` and the appropriate test-environment compile after PR-02; targeted `mix test` files listed below, plus the new audit tests delivered by the slice.
- For schema work only: generate each migration with `mix ecto.gen.migration <descriptive_name>`, then implement explicit `up/0` and `down/0`. Rehearsal commands and disposable database identities must be recorded in the storage design before execution; do not put a destructive copy-paste command against the shared database here.
- Scenario work: validate actual YAML with `Oli.Scenarios.validate_file/1`, then execute its ExUnit runner with real directives/application paths. Final browser acceptance uses the configured Playwright workflow; use `run-server` on port 4000 if local UI verification is needed.
- If TypeScript/React changes are actually needed, run targeted tests, lint and formatting under `assets/`; otherwise do not add unrelated frontend work.

## Implementation PRs

| PR | Jira | Scope | Dependencies |
| --- | --- | --- | --- |
| PR-01 | MER-6111 | Event contracts, partitioned storage, and central-history migration | Reviewed storage/contract design |
| PR-02 | MER-6112 | Boundary and CI with audited user-deletion pilot | PR-01 |
| PR-03 | MER-6113 | Coverage: identity and platform administration | PR-02 |
| PR-04 | MER-6114 | Coverage: authoring, projects, imports, and repairs | PR-03 |
| PR-05 | MER-6115 | Coverage: delivery and configuration | PR-04 |
| PR-06 | MER-6116 | Coverage: learner administration and administrative operations | PR-05 |
| PR-07 | MER-6117 | Audit Log UI and search | PR-06 |

## Phase 1: Event contracts, partitioned storage, and central-history migration

- PR: **PR-01**; one proposed Sub-task.
- Relative size: Large: contracts, storage and migration/recovery. This is not a time estimate or a trigger to split.
- Goal: Full event catalog, safe schema/validation and factory insert tests; partitions, historical central-data conversion, retirement and history-preserving rollback.
- Requirements: FR-001, FR-002, FR-029, FR-030, FR-031, FR-032, FR-034, FR-039 plus the common invariants.
- Risk: Large storage/migration scope; rehearse locking, copy/retirement and rollback, and justify partition interval with evidence.
- Source/entry-point/test details: work areas W01 in `coverage-inventory.md`; these are internal blocks, not extra PRs.

### Tasks

- [ ] Before DDL, complete the field/action contract matrix from the domain changesets and the FDD catalog. Build valid and invalid factory-backed inserts for every admitted event, including future producer families, reset semantics, deleted subjects, bulk and async outcomes.
- [ ] Implement shared context/builders, conditional v1/v2 checks, safe snapshots, indexed partitioned storage and compatible readers. Adapt current producers only as needed to keep their existing events writing strict v2; do not silently accept new v1 rows or invent missing actors.
- [ ] Generate explicit up/down migrations; implement copy, validation, swap, same-deployment retirement, safe rollback archive and roll-forward. Primary path: one transactional migration with no `Oli.Release` change. Use the batched/resumable fallback with a guarded release sequence only if rehearsal at production volume requires it (see the PR-01 detailed design).
- [ ] Benchmark six-month versus annual partitions with stated volume assumptions; provision and test future partitions, missing-partition failure, privileges, diagnostics and both Oban configurations. Document maintenance, retirement and recovery gates.

### Testing Tasks

- [ ] Test every catalog case against PostgreSQL; reject invalid direct inserts; retain existing capture/read/producer assertions.
- [ ] Rehearse interruptions, redaction, historical nulls, composite lookups, sequence allocation, Jan/Jul boundaries, immediate rollback and rollback after new event types. Record locks, WAL, storage and elapsed time on an isolated database.
- [ ] Keep the existing Audit Log usable with new types before the final UI PR. Confirm the legacy source is retired only after readiness checks, in this PR and the eventual single deployment.
- [ ] Apply the common actor/privacy/authorization/atomicity/cardinality and supported-entry tests throughout the PR; update actual proof references.
- Existing regression command (only after isolated DB verification): `mix test test/oli/auditing_test.exs test/oli_web/live/admin/audit_log_live_test.exs test/oli/delivery/section_creation_test.exs`. Add the new audit tests for each internal block.

### Definition of Done

- The entire PR scope and supported callers satisfy their contracts, regression and new audit tests pass, and no protected field retains an unaudited shortcut.
- Required review/CI and the phase-specific gate pass; evidence is recorded, with no claim that this intermediate integration can deploy alone.

### Gate

- All contracts have real insert/reject tests; historical conversion, same-deployment retirement and safe rollback pass isolated rehearsal. Approve the concrete schema and maintenance procedure before implementation.

### Dependencies

- Reviewed PRD/FDD and storage detailed design.

### Parallelizable Work

- Test-case and internal design preparation can overlap; shared context/schema edits remain coordinated. Internal blocks stay in this PR. No parallel branches/agents are authorized by this note.

## Phase 2: Boundary and CI with audited user-deletion pilot

- PR: **PR-02**; one proposed Sub-task.
- Relative size: Medium: one real action and architecture enforcement. This is not a time estimate or a trigger to split.
- Goal: Private raw mutations, shared audited coordination, a real user-deletion action, compiled Boundary enforcement and CI.
- Requirements: FR-003, FR-004, FR-007, FR-029, FR-035, FR-036 plus the common invariants.
- Risk: Boundary topology must be compiled and proved; field-level/direct-SQL/dynamic bypasses need tests and inspection.
- Source/entry-point/test details: work areas W02 in `coverage-inventory.md`; these are internal blocks, not extra PRs.

### Tasks

- [ ] Install/configure Boundary and extract only the selected user-deletion mutation. Implement the actor-aware coordinator, historical identity capture and shared transaction; remove duplicate manual capture.
- [ ] Classify callers and protect only the audited account internals, as narrowed by the owner on 2026-11-03. Preserve existing cross-context calls. Prove read-context, web and Scenario callers cannot statically call the private mutation; retain outgoing checks on callers and incoming checks on the independent audited boundary.
- [ ] Enable the Boundary compiler in the existing warnings-as-errors CI builds (no `--force`: Boundary rechecks stored references on every compile). Serialize concurrent deletions with a lock on the target user row; a repeated attempt finds no user and appends nothing. No replay protocol in this pilot (owner decision, 2026-11-03): replay is designed in the first asynchronous workflow (PR-04).

### Testing Tasks

- [ ] Prove real delete + event, unchanged route authorization, mutation failure and injected audit failure rollback; concurrent deletions of the same user commit exactly one semantic success.
- [ ] Run allowed and intentionally forbidden compilation fixtures; document .exs/test-support checking limits and direct SQL/dynamic invocation limits.
- [ ] Apply the common actor/privacy/authorization/atomicity/cardinality and supported-entry tests throughout the PR; update actual proof references.
- Existing regression command (only after isolated DB verification): `mix test test/oli/accounts_test.exs test/oli_web/live/users`. Add the new audit tests for each internal block.

### Definition of Done

- The entire PR scope and supported callers satisfy their contracts, regression and new audit tests pass, and no protected field retains an unaudited shortcut.
- Required review/CI and the phase-specific gate pass; evidence is recorded, with no claim that this intermediate integration can deploy alone.

### Gate

- Compiled allowed/forbidden examples and real transaction tests pass before broad Boundary replication.

### Dependencies

- PR-01 and its transitive prerequisites.

### Parallelizable Work

- Test-case and internal design preparation can overlap; shared context/schema edits remain coordinated. Internal blocks stay in this PR. No parallel branches/agents are authorized by this note.

## Phase 3: Coverage: identity and platform administration

- PR: **PR-03**; one proposed Sub-task.
- Relative size: Large coverage group: implement and review by internal domain blocks within one PR. This is not a time estimate or a trigger to split.
- Goal: Accounts, profiles, access rights, authentication/recovery, organizations and consent configuration, LMS/SSO/LTI and external-tool/roster/grade-passback configuration, AI services, API/MCP credentials and feature flags/rollouts.
- Requirements: FR-006, FR-007, FR-025, FR-026, FR-029, FR-037 plus the common invariants.
- Risk: Large account/integration surface and secret-bearing inputs; shared generic updates and session boundaries need careful ownership.
- Source/entry-point/test details: work areas W05, W06, W07, W23, W24, W25, W26 in `coverage-inventory.md`; these are internal blocks, not extra PRs.

### Tasks

- [ ] Extract protected access mutations and move existing role/internal-flag/delete capture into shared coordination without duplicates.
- [ ] Route generic updates of protected fields through the same policy. Compose collaborator invitation cleanup with author deletion without independently committing the inner action.
- [ ] Classify every generic account write by persisted field. Extract audited creation/profile/link operations while preserving provider, invitation and verification behavior.
- [ ] Make technical provisioning/Setup PW attribution explicit; subsequent represented actions retain their actual human actor. Migrate supported Scenario and provider entry points, including bootstrap helpers.
- [ ] Preserve domain validation and safe response shapes; do not serialize password/email-verification inputs as arbitrary audit details.
- [ ] Map every password, SSO/OAuth and LTI login, logout and session-invalidating password path, including the lower-level create/install helpers, to one semantic issuance/revocation boundary.
- [ ] Compose account linking and necessary profile/preferences writes without recapturing login. Define token persistence versus cookie delivery and server-side revocation semantics.
- [ ] Audit recovery lifecycle without storing tokens or credential hashes; document retry behavior (a reused one-time token fails and records no new success) and secret-bearing response limits.
- [ ] Introduce typed organization scopes and migrate settings/association writers, including bulk community membership and publisher defaults.
- [ ] Audit research-consent configuration separately from an individual accepting consent or saving preferences.
- [ ] Map organization/platform/section configuration inputs and safe-field policies; never capture JWKS secrets, signed launches or external credentials.
- [ ] Coordinate registration/deployment and external-tool relationship changes, preserving existing provisioning and deep-link flows; compose with remix/publication operations without duplicates.
- [ ] Explicitly locate roster synchronization and grade-passback policy writers, distinguishing them from routine synchronization/reporting.
- [ ] Implement provider/configuration safe projections and credential lifecycle builders using stable non-secret IDs.
- [ ] Route admin and project credential callers with actor/owner separation; preserve one-time credential responses without putting their values or hashes into audit data.
- [ ] Move existing capture ownership to shared audited coordinators while preserving the seven event names and typed scope.
- [ ] Keep atomic feature-group behavior and post-commit cache invalidation; update all helper callers rather than layering a second capture.
- [ ] Implement the account/access/provisioning and auth work first, then organization/integration/service/credential/flag configuration within this same PR. Do not turn these internal blocks into separate PRs.
- [ ] Use existing project/section interfaces for integrations and credential ownership. Later authoring/delivery PRs compose these already-audited policies; they are not prerequisites for creating new organization or credential audit commands. Preserve a protected-key ownership map across generic updates.
- [ ] Keep remaining account preferences in PR-06 to honor their lower priority. Necessary login-related preference writes retain behavior and are explicitly completed by that later coverage PR.

### Testing Tasks

- [ ] Verify actor versus subject, role snapshots, deleted author identity, collaborator cancellation, unauthorized changes, no-op and audit failure rollback.
- [ ] Exercise public registration, invited/provisioned accounts, link/unlink and profile changes across actual callers; no fabricated success on failed verification.
- [ ] Verify Setup PW creates accounts under a system actor, and user/author identities remain distinct; run full suite if shared fixture/support configuration changes.
- [ ] Test each supported authentication channel, forced revocation and repeated callbacks; fail token/audit writes independently and assert atomicity.
- [ ] Test wrong credentials/invalid recovery tokens and cookie/response failures without false success; scan events, job args and safe logs for marker secrets.
- [ ] Verify safe identities after soft deletion, tenant boundaries, association changes and consent configuration diffs; exclude personal consent payloads.
- [ ] Test signing/credential redaction markers, tenant isolation, registration lifecycle, deep-link replacement and policy no-ops; preserve LTI authoring/remix/publication regression scenarios.
- [ ] Test each supported lifecycle transition and ownership boundary, config secret fields at every nesting level, no-op status updates and rollback on audit failure.
- [ ] Retain existing audit integration assertions and add before/after, mixed no-op groups, scope, rollback and concurrency cases.
- [ ] Apply the common actor/privacy/authorization/atomicity/cardinality and supported-entry tests throughout the PR; update actual proof references.
- Existing regression command (only after isolated DB verification): `mix test test/oli/accounts_test.exs test/oli/accounts/collaborator_test.exs test/oli_web/controllers/collaborator_controller_test.exs test/oli/lti_accounts_test.exs test/oli_web/live/user_registration_live_test.exs test/oli/scenarios/demo_accounts_test.exs test/oli_web/user_auth_test.exs test/oli_web/author_auth_test.exs test/oli/accounts/secure_session_test.exs test/oli/institutions_test.exs test/oli/groups/community_test.exs test/oli/inventories/publisher_test.exs test/oli_web/live/community_live_test.exs test/oli/lti/platform_external_tools_test.exs test/oli_web/controllers/registration_controller_test.exs test/scenarios/lti_external_tool/section_configuration_test.exs test/oli/gen_ai_test.exs test/oli/mcp/auth_test.exs test/oli/mcp/auth_integration_test.exs test/oli/scoped_feature_flags/audit_integration_test.exs test/oli/scoped_feature_flags/rollouts_test.exs test/oli/scoped_feature_flags_test.exs`. Add the new audit tests for each internal block.

### Definition of Done

- The entire PR scope and supported callers satisfy their contracts, regression and new audit tests pass, and no protected field retains an unaudited shortcut.
- Required review/CI and the phase-specific gate pass; evidence is recorded, with no claim that this intermediate integration can deploy alone.

### Gate

- All account/integration/configuration blocks are covered, including generic writes and secret-bearing/session paths; preserve later domain composition interfaces.

### Dependencies

- PR-02 and its transitive prerequisites.

### Parallelizable Work

- Test-case and internal design preparation can overlap; shared context/schema edits remain coordinated. Internal blocks stay in this PR. No parallel branches/agents are authorized by this note.

## Phase 4: Coverage: authoring, projects, imports, and repairs

- PR: **PR-04**; one proposed Sub-task.
- Relative size: Large coverage group: implement and review by internal domain blocks within one PR. This is not a time estimate or a trigger to split.
- Goal: Project lifecycle, duplication/import, publishing, ownership/collaborators, project settings, authoring defaults/banks/objectives/curriculum, destructive content/media changes, imports and repairs. Project/content DOT settings compose the shared policy owned with delivery configuration.
- Requirements: FR-005, FR-008, FR-011, FR-013, FR-016, FR-017, FR-027, FR-029, FR-037 plus the common invariants.
- Risk: Revision-based deletion, composed publishing and partially committed/external imports; async recovery must be proved with the actual workflows.
- Source/entry-point/test details: work areas W09, W10, W11, W19, W20 in `coverage-inventory.md`; these are internal blocks, not extra PRs.

### Tasks

- [ ] Create composable lifecycle/relationship operations and route UI/controller/Scenario callers; classify deletion/status and ownership keys in update_project.
- [ ] Relocate project_published capture into the invocation coordinator; distinguish pending publication bookkeeping from actual publication.
- [ ] Define the boundary used by later import workers: project creation is a committed lifecycle event, but it is not proof that the whole import completed.
- [ ] Move destructive orchestration to protected authoring boundaries, including generic resource edits and page-content rewrites that remove embedded activities.
- [ ] Preserve resource/revision IDs, editing locks and relevant relationship changes; propagate actor through API/MCP/Scenario entry points where supported.
- [ ] Classify metadata soft-deletion separately from any external object deletion; use the async protocol if a destructive external step is actually supported.
- [ ] Migrate import/repair entry points and workers through audited orchestration, carrying initiator and stable operation identity across dispatch.
- [ ] Preserve google_doc_imported coverage, inspect RepairResult status, and emit confirmed per-target and aggregate outcomes for committed chunks.
- [ ] Inventory administrative replacement/removal entry points outside the named modules, assigning each to this slice, learner restoration or ClickHouse; no unowned catch-all.
- [ ] Complete the project-setting key map, composing with lifecycle/DOT policies already migrated; protect generic update_project and relationship writers.
- [ ] Capture safe experiment/alternative, activity/tool availability and required-survey diffs, excluding transient UI and runtime experiment assignments.
- [ ] Enumerate configuration changes inside revision/content structures and route API, authoring workspace, MCP and supported Scenario writers.
- [ ] Capture objective relationships, bank rules and defaults while retaining edit locks and immutable publication semantics; reuse destructive events from PR-04 without recapture.
- [ ] Establish Oban initiation, confirmed outcome, retry/reconciliation and pruning safeguards when implementing the first actual asynchronous import/repair flow in this PR. This is internal work, not an infrastructure or ClickHouse pilot PR. Local-only operations do not need jobs.
- [ ] Implement project/content DOT configuration through a reusable field policy and document the interface that PR-05 will extend for section/recommendation settings. Do not defer an unaudited project configuration path after this PR claims it is migrated.

### Testing Tasks

- [ ] Preserve create/duplicate/publish assertions and publication immutability; assert rollback, collaborator cleanup composition and original author attribution in Scenarios.
- [ ] Exercise each target kind plus bulk partial/failed inputs, deleted identity, nested delete cardinality and edit-lock rejection. Add API/MCP entry tests rather than testing only builders.
- [ ] Test full success, partial repair, failed result inside an ok tuple, crash between chunks and safe resume; assert no repeated target successes or secret source URLs.
- [ ] Test each admitted settings family and mixed-field updates; preserve publication/version behavior and exclude analytics/export cache URL updates.
- [ ] Verify defaults versus delivery overrides, nested objective deletion/attachment, bank rule changes, curriculum edits and failed lock checks. Include representative MCP and real Scenario coverage.
- [ ] Apply the common actor/privacy/authorization/atomicity/cardinality and supported-entry tests throughout the PR; update actual proof references.
- Existing regression command (only after isolated DB verification): `mix test test/oli/course_test.exs test/oli/publishing_test.exs test/oli/accounts/collaborator_test.exs test/oli_web/controllers/collaborator_controller_test.exs test/oli/editing/resource_editor_test.exs test/oli/editing/page_editor_test.exs test/oli_web/controllers/api/activity_bank_controller_test.exs test/oli/google_docs/import_test.exs test/oli/interop/ingest_test.exs test/oli/authoring/project_repair_test.exs test/oli/experiments/configuration_test.exs test/oli/activities/activity_registration_project_test.exs test/oli/editing/objective_editor_test.exs`. Add the new audit tests for each internal block.

### Definition of Done

- The entire PR scope and supported callers satisfy their contracts, regression and new audit tests pass, and no protected field retains an unaudited shortcut.
- Required review/CI and the phase-specific gate pass; evidence is recorded, with no claim that this intermediate integration can deploy alone.

### Gate

- Authoring semantics, imports and repairs are covered. Before relying on async auditing, prove retry/terminal capture/pruning and external reconciliation inside this PR; no separate ClickHouse gate PR.

### Dependencies

- PR-03 and its transitive prerequisites.

### Parallelizable Work

- Test-case and internal design preparation can overlap; shared context/schema edits remain coordinated. Internal blocks stay in this PR. No parallel branches/agents are authorized by this note.

## Phase 5: Coverage: delivery and configuration

- PR: **PR-05**; one proposed Sub-task.
- Relative size: Large coverage group: implement and review by internal domain blocks within one PR. This is not a time estimate or a trigger to split.
- Goal: Assessment settings and settings_changes migration, student exceptions/exemptions, section/product/blueprint lifecycle and settings, DOT/activation/recommendation configuration, remixes, publication updates, gating and scheduling, discussion/notes/student-support configuration.
- Requirements: FR-009, FR-010, FR-011, FR-012, FR-018, FR-020, FR-021, FR-022, FR-029, FR-033, FR-037 plus the common invariants.
- Risk: Bulk/default/exception semantics, historical secrets, shared section writes and background publication updates.
- Source/entry-point/test details: work areas W03, W04, W13, W14, W16, W17, W21 in `coverage-inventory.md`; these are internal blocks, not extra PRs.

### Tasks

- [ ] Move single/bulk/reset writes into audited composition; derive diffs from locked persisted values and preserve secure-delivery/adaptive/already-started rules.
- [ ] Keep auto-submit changes in the transaction and cache invalidation after commit. Replace historical writes and test readers with central events.
- [ ] Migrate safe source rows with provenance/new IDs and explicit unknowns; sanitize password history, verify external consumers and rollback redaction, then retire settings_changes in this slice.
- [ ] Introduce the audited exception boundary and migrate direct and bulk callers, including Scenarios.
- [ ] Reuse setting-field policies; identify the instructor actor separately from the student subject and keep auto-submit consistency.
- [ ] Enumerate persisted DOT/activation keys at all three scopes, including revision content edits; migrate configuration writers and safe prompt projections.
- [ ] Audit toggles and saved instructor prompts through section coordination. Treat trigger-point invocation as an exclusion/control case: its API invokes runtime behavior, not a settings mutation.
- [ ] Audit the committed diff at Remix.save, preserving the existing transaction across hierarchy, materialization and external-tool deep-link mappings.
- [ ] Coordinate manual and worker publication updates with initiator/system attribution, and replay semantics for the worker path; audit auto-update policy changes independently.
- [ ] Compare persisted before/after curriculum per semantic entry; do not capture each intermediate in-memory drag or helper call.
- [ ] Reuse the existing section-creation transactional sink pattern and consolidate all manual captures, including Scenario creation.
- [ ] Classify the entity type and lifecycle/status transition; route API, author workspace, instructor creation and source-copy paths with correct actor.
- [ ] Protect lifecycle keys in generic section updates; preserve automatic enrollment and other creation side effects without duplicate parent events.
- [ ] Inventory remaining persisted configuration keys and map each to this slice or its named specialized owner (assessment, DOT, remix, gating, payment, certificates, integrations).
- [ ] Close generic update paths for these fields across all three entity types, including support links/options and required surveys. Keep automatic cache/analytics fields explicitly excluded.
- [ ] Coordinate conditions and their derived indexes in one transaction, with one event per semantic condition or changed scheduled resource.
- [ ] Migrate scheduling update/clear APIs, preserving effective dates and post-commit depot invalidation.
- [ ] Migrate and sanitize settings_changes, change its writers/readers and retire it with assessment-settings work in this PR; do not move this second history into PR-01.
- [ ] Own discussion/notes/support configuration here; PR-06 owns post/thread moderation. Reuse PR-03 integration configuration and PR-04 project/content DOT and async policies rather than duplicating their events.

### Testing Tasks

- [ ] Verify every supported setting, mixed changed/unchanged bulk targets, default removal/effective values and rollback of auto-submit changes.
- [ ] Rehearse source-ID collisions, restartable conversion, legacy string types, password redaction, safe down/roll-forward and absence of dual writes.
- [ ] Cover create/update/delete, no-op, eligible and ineligible bulk targets, actual before/effective values, actor/subject isolation and audit failure rollback.
- [ ] Verify project/section/content scope, actual saved prompt/config changes, bulk conditions and no-op behavior; ordinary trigger execution/chat must not become settings audit.
- [ ] Test cancel/no-op save, reorder/add/remove/source changes, retained deep links, failed save and worker retries. Preserve multi-source and major-update regressions.
- [ ] Retain section-creation audit failure rollback tests; cover all three entity types, source copies, archival/deletion and Setup PW followed by instructor attribution.
- [ ] Cover safe field diffs, defaults, product/blueprint authorization, required-survey relationships and mixed-attribute updates crossing already migrated policies.
- [ ] Cover bulk mixed/no-op schedules, prerequisite nesting, reset/clear, invalid dates and audit rollback; assert no duplicate derived-index events.
- [ ] Apply the common actor/privacy/authorization/atomicity/cardinality and supported-entry tests throughout the PR; update actual proof references.
- Existing regression command (only after isolated DB verification): `mix test test/oli/delivery/settings_test.exs test/oli/delivery/sections/assessment_settings_test.exs test/scenarios/delivery/assessment_settings/assessment_settings_test.exs test/oli/delivery/settings/student_exceptions_test.exs test/oli/experiments/configuration_test.exs test/oli_web/live/components/sections/instructor_ai_recommendations_component_test.exs test/oli_web/controllers/api/trigger_point_controller_test.exs test/oli/scenarios/remix_test.exs test/scenarios/delivery/remix_product_sources_test.exs test/scenarios/lti_external_tool/publication_update_test.exs test/oli/delivery/section_creation_test.exs test/oli/delivery/sections/blueprint_test.exs test/oli_web/controllers/api/product_controller_test.exs test/oli/sections_test.exs test/oli/delivery_test.exs test/oli/delivery/sections/scheduling_test.exs test/oli_web/controllers/api/scheduling_controller_test.exs test/oli_web/live/sections/gating_and_scheduling_test.exs`. Add the new audit tests for each internal block.

### Definition of Done

- The entire PR scope and supported callers satisfy their contracts, regression and new audit tests pass, and no protected field retains an unaudited shortcut.
- Required review/CI and the phase-specific gate pass; evidence is recorded, with no claim that this intermediate integration can deploy alone.

### Gate

- Assessment history is safely consolidated/retired, all delivery blocks pass, and existing integrations/authoring/job policies compose without duplicate events.

### Dependencies

- PR-04 and its transitive prerequisites.

### Parallelizable Work

- Test-case and internal design preparation can overlap; shared context/schema edits remain coordinated. Internal blocks stay in this PR. No parallel branches/agents are authorized by this note.

## Phase 6: Coverage: learner administration and administrative operations

- PR: **PR-06**; one proposed Sub-task.
- Relative size: Large coverage group: implement and review by internal domain blocks within one PR. This is not a time estimate or a trigger to split.
- Goal: Enrollment/invitations/instructor access, moderation/deletion, attempt/grade/progress interventions, payments/discounts/codes/manual entitlements, certificates, ClickHouse administrative outcomes and remaining persisted account preferences.
- Requirements: FR-005, FR-014, FR-015, FR-019, FR-022, FR-023, FR-024, FR-027, FR-028, FR-029, FR-039, FR-040 plus the common invariants.
- Risk: Administrative writes overlap normal learning and external processing; distinguish real outcomes, actors/subjects and routine activity.
- Source/entry-point/test details: work areas W08, W12, W15, W18, W22, W27 in `coverage-inventory.md`; these are internal blocks, not extra PRs.

### Tasks

- [ ] Replace Task.start execution with transactional initiated-event + Oban enqueue under domain orchestration, preserving admin capabilities and progress presentation.
- [ ] Design and prove terminal capture for success, exhaustion, cancellation and crash, including safe evidence retention versus the configured Pruner. Reuse domain evidence before proposing new storage.
- [ ] Specify external-effect reconciliation and explicit unknown outcomes; never blindly repeat destructive work after an uncertain response. Review the actual three ClickHouse kinds separately.
- [ ] Relocate existing resource_attempt_deleted capture; introduce shared intervention operations for reset, restore, manual score and regrade.
- [ ] Extract direct Repo updates from restore-user-progress orchestration; preserve source/target learner identity, grades and related attempt references.
- [ ] Apply the async/partial protocol where actual workflows need it; keep ordinary scoring, student reset/retry flows and automatic recalculation outside administrative event categories.
- [ ] Introduce audited deletion/moderation and configuration operations; migrate the actorless soft_delete_post overload and direct generic post-status changes.
- [ ] Record actor versus post author and cascade/thread scope with minimal identity; route discussion and notes settings wherever their configuration is actually stored.
- [ ] Compose account provisioning/invitation and enrollment operations without duplicate creation events; preserve existing invite and role semantics.
- [ ] Migrate instructor-access and bulk roster callers, including Scenarios. Distinguish provider/system provisioning from a human administrative change.
- [ ] Group these two bounded section-admin contexts while keeping independent event contracts. Audit money/currency and beneficiary references without payment instruments or redeemable codes.
- [ ] Protect certificate configuration and administrative decisions, separating them from automatic qualification, PDF generation and mail delivery. Route any durable administrative jobs through PR-8 semantics.
- [ ] Finish account field ownership and route preference updates through audited operations, composing authentication-time preferences without duplicating session events.
- [ ] Enumerate persisted keys and safe values; exclude local browser state and derived counters. Schedule this slice after the higher-priority access/destructive slices even where technical dependencies are fewer.
- [ ] Migrate the actual ClickHouse operations here using the async pattern developed within prior coverage work; there is no separately planned ClickHouse pilot or PR.
- [ ] Finish remaining persisted preferences after access/destructive work, including authentication composition. Keep individual consent preferences distinct from organization consent configuration.

### Testing Tasks

- [ ] Inject enqueue/audit failures; test duplicate enqueue, retries, external success before local persistence, exhaustion and cancellation outside the worker.
- [ ] Test an outage longer than the pruning interval and subsequent recovery; confirm evidence remains available after legitimate job pruning. Fixed retention or telemetry alone is not a passing solution.
- [ ] Test instructor/admin actor distinct from learner, rollback after partial local work, restored progress, manual grade values and regrade result classification.
- [ ] Prove ordinary submissions/automatic scoring produce no new administrative event. Add focused restore tests if none exist for the extracted operation.
- [ ] Cover self versus moderator deletion, whole threads, unauthorized moderation, no-op configuration and audit failure rollback; no copied message body or ordinary post/reaction audit.
- [ ] Cover actor versus invited/student subject, secret-free invitation identity, already enrolled/no-op, mixed bulk targets, authorization and transaction rollback.
- [ ] Exercise discounts, code batches/transfers and manual entitlement changes; verify actor versus recipient for certificate decisions and no secrets in events/errors.
- [ ] Inject downstream job failure without turning a committed grant into a false failed grant; distinguish decision and delivery outcomes if delivery is in scope.
- [ ] Test saved changes/no-ops, nested values and consent privacy; assert transient UI, ordinary page views/answers and automatic scoring stay excluded.
- [ ] Apply the common actor/privacy/authorization/atomicity/cardinality and supported-entry tests throughout the PR; update actual proof references.
- Existing regression command (only after isolated DB verification): `mix test test/oli/clickhouse/admin_operations_test.exs test/oli/delivery/attempts/manual_grading_test.exs test/oli_web/live/manual_grading/manual_grading_view_test.exs test/oli/resources/collaboration_test.exs test/oli_web/live/collaboration_live_test.exs test/oli/sections_test.exs test/oli/delivery/sections/enrollment_guard_test.exs test/oli/delivery/sections/enrollments_browse_test.exs test/oli/delivery/paywall_test.exs test/oli/delivery/certificates_test.exs test/oli/delivery/granted_certificates_test.exs test/oli_web/controllers/granted_certificates_controller_test.exs test/oli/accounts_test.exs test/oli_web/user_auth_test.exs test/oli_web/author_auth_test.exs`. Add the new audit tests for each internal block.

### Definition of Done

- The entire PR scope and supported callers satisfy their contracts, regression and new audit tests pass, and no protected field retains an unaudited shortcut.
- Required review/CI and the phase-specific gate pass; evidence is recorded, with no claim that this intermediate integration can deploy alone.

### Gate

- Learner/admin/ClickHouse/preferences blocks pass, routine learning remains excluded and final job outcomes survive pruning.

### Dependencies

- PR-05 and its transitive prerequisites.

### Parallelizable Work

- Test-case and internal design preparation can overlap; shared context/schema edits remain coordinated. Internal blocks stay in this PR. No parallel branches/agents are authorized by this note.

## Phase 7: Audit Log UI and search

- PR: **PR-07**; one proposed Sub-task.
- Relative size: Medium/large: query, presentation and investigation verification. This is not a time estimate or a trigger to split.
- Goal: Human-readable new and historical events; actor/entity/action/date/project/section search, deleted identities, safe details, administrator-only access and measured paging/query performance.
- Requirements: FR-034, FR-035, FR-039 plus the common invariants.
- Risk: Historical search, deleted identities, pagination counts and all-history query cost.
- Source/entry-point/test details: work areas W28 in `coverage-inventory.md`; these are internal blocks, not extra PRs.

### Tasks

- [ ] Implement the approved investigation filters and safe snapshot-based text search with current-identity compatibility, UTC bounds, parameter validation and stable paging.
- [ ] Render actor/affected subject, multi-field changes, settings history, deleted/system/unknown identities and confirmed async outcomes. Keep admin-only authorization and avoid exposing schema plumbing.
- [ ] Benchmark actual predicates/indexes over representative multi-partition history; fix measured query costs and validate keyboard/labels/details behavior.

Carried over from PR-01 (measured or found during PR-01; see `evidence/pr-01-storage.md`):

- Replace the admin list query shape. `count(*) OVER()`, the left joins, and the OR'ed joined-name `to_tsvector` read every matching row: the default page takes about 0.5 s and text search about 1.8 s at the 440,000 rows PR-05 brings, and 30 to 66 s at 10M. Options: an estimated or capped count, keyset pagination, and a `search_text`-only match using the GIN index.
- Make text search safe for malformed input. `to_tsquery` raises on input such as unmatched parentheses or trailing operators. Switching to `websearch_to_tsquery` or `plainto_tsquery` would drop the current prefix matching (`:*`), so choose the parser together with the new search semantics.
- `get_event!/1` (lookup by ID alone, across all partitions) was removed because nothing called it. If the event detail view needs a lookup without `inserted_at`, reintroduce it with that caller as justification.

Idea to explore (not a requirement or acceptance criterion): filtering by event family, derived from `EventCatalog` as `event_type IN (<family types>)`. Options include a separate family selector or an action selector grouped by family where a whole family can be chosen. Catalog descriptions could also serve as action tooltips. Evaluate during PR-07 design; adopting it requires owner agreement.

### Testing Tasks

- [ ] Test every event family rendering, deleted-name search, legacy data, empty/deep pages, equal timestamps, time boundaries and unauthorized requests.
- [ ] Verify query plans/partition pruning, bounded page size and no secret search indexing; conduct manual administrator investigation on the integrated preview.
- [ ] Apply the common actor/privacy/authorization/atomicity/cardinality and supported-entry tests throughout the PR; update actual proof references.
- Existing regression command (only after isolated DB verification): `mix test test/oli/auditing_test.exs test/oli_web/live/admin/audit_log_live_test.exs`. Add the new audit tests for each internal block.

### Definition of Done

- The entire PR scope and supported callers satisfy their contracts, regression and new audit tests pass, and no protected field retains an unaudited shortcut.
- Required review/CI and the phase-specific gate pass; evidence is recorded, with no claim that this intermediate integration can deploy alone.

### Gate

- Every coverage PR is integrated; readable/searchable history, deleted identities, authorization and measured query behavior pass.

### Dependencies

- PR-06 and its transitive prerequisites.

### Parallelizable Work

- Test-case and internal design preparation can overlap; shared context/schema edits remain coordinated. Internal blocks stay in this PR. No parallel branches/agents are authorized by this note.

## Phase 8: Complete integration acceptance and release readiness

- Goal: verify MER-6066 as a whole at the final integration revision; this is parent-ticket acceptance, not an eighth implementation PR/subtask.
- Dependencies: PR-01 through PR-07 merged with developer review and passing checks.

### Tasks

- [ ] Reconcile the action/field/caller inventory with current master/integration changes. Confirm the original 16 events, every Jira action family, every supported channel, and Scenario bootstrap/human attribution. Remove or verify any transitional capture adapter; no unprotected mutation path remains for in-scope work.
- [ ] Run combined schema migration, settings-history conversion, same-deployment source retirement and rollback/roll-forward rehearsal using the complete release, including pending job handling. Recheck actual volume, privileges, maintenance/backup capacity and partition scheduler ownership.
- [ ] Follow personal confirmation stages for any required sync/commits/publication and final integration PR. Its head is `story/MER-6066-audit-log-expansion`, base `master`; use the personal `[INTEGRATION] [MER-6066]` convention and `Integration Branch` label after verifying current validation/availability.
- [ ] Record parent criteria, integration PR, exact SHA and running preview image in the QA handoff. Fix defects through implementation PRs into integration; rerun acceptance after fixes/syncs change the revision. Enter the master merge queue only with current QA approval and required checks.

### Testing Tasks

- [ ] Run the full backend suite on the verified isolated database, normal CI frontend/Playwright gates, and real Scenario flows: Setup PW creates accounts, author creates/publishes, instructor creates/enrolls/configures, student answers without new administrative audit.
- [ ] Exercise central investigation for current/historical/deleted entities and async initiated/success/failed/partial/unknown outcomes; test unauthorized access and secret-marker absence across persisted/serialized sinks.
- [ ] Collect final single/bulk write and search benchmarks, partition/replay plans, and terminal-event recovery evidence. Rehearse outage, job pruning and rollback while preserving new history.
- Commands: `mix test` only after isolation verification; the repository's current required CI and Playwright workflow at the final revision. Repeat only when a new change/failure justifies it.

### Definition of Done

- All 40 FR / 105 AC have implementation/verification evidence, not merely document references. No criterion is marked implemented by a passing structural script alone.
- The final tested preview revision passes QA, required checks and deployment/recovery gates; approval/publication actions remain explicit stages.

### Gate

- Current-revision QA approval plus release readiness. Neither child completion nor an old preview approval is sufficient.

### Parallelizable Work

- QA preparation and operating-procedure review can begin earlier; final results must reference the integrated revision.

## Parallelization Notes

Prefer the sequential PR order while sharing Accounts, Course, Sections and Institutions files. Prepare test cases or design blocks concurrently only where useful; that does not create new branches/PRs. Keep scenario changes with their actual domain block. Minimal UI compatibility is in PR-01 and comprehensive UI/search follows all coverage. Actual execution evidence, followed by owner agreement, is the only trigger for reconsidering a coverage split.

## Phase Gate Summary

| Gate | Required evidence | Owner |
| --- | --- | --- |
| Storage | Full payload model and insert cases; partition rationale; guarded migration, retirement and recovery | PR-01 |
| Architecture | Static Boundary/CI proof and real action + audit transaction | PR-02 |
| Domain coverage | Caller/field map, per-block tests, no duplicate events or unsafe bypass | Each of PR-03–PR-06 |
| Async correctness | Actual job retries/terminal outcomes, crash recovery and pruning; no speculative registry | First async workflow in PR-04; reused/verified in PR-05/06 |
| Settings history | Sanitized conversion, effective settings intact, source retired safely | PR-05 |
| Investigation | Search/display/access control and query evidence | PR-07 |
| Parent acceptance | All criteria with proof at the actual integrated revision and deployment readiness | Phase 8 / MER-6066 |

## Requirement-to-phase traceability

Document status describes planning coverage, not implemented behavior. Phase 8 verifies all criteria together. Shared invariants are tested in every coverage PR even when the table names the phase that establishes the mechanism.

| Requirement | Criteria | Primary phases | Verification route |
| --- | --- | --- | --- |
| FR-001 | AC-001, AC-002, AC-003, AC-004 | 1, 2 | Catalog inserts and actor/subject/concurrent-diff cases |
| FR-002 | AC-005, AC-006, AC-007 | 1 | Every contract valid/invalid plus direct DB rejects |
| FR-003 | AC-008, AC-009, AC-010 | 2 | Real mutation/audit failure injection and no-op tests |
| FR-004 | AC-011, AC-012, AC-013, AC-014 | 2, 5, 6 | Supported callers, nested/bulk cardinality and retried operation tests |
| FR-005 | AC-015, AC-016, AC-017, AC-018 | 4, 5, 6 | Job failure/cancel/crash/pruning and external reconciliation |
| FR-006 | AC-019, AC-020, AC-021 | 3 | All auth adapters, server session boundaries and failed callback checks |
| FR-007 | AC-022, AC-023, AC-024 | 2, 3 | Access/profile/link/provision/recovery/delete tests |
| FR-008 | AC-025, AC-026, AC-027 | 4 | Lifecycle/publish/collaborator/import regressions |
| FR-009 | AC-028, AC-029, AC-030 | 5 | Single/bulk/reset settings and safe password markers |
| FR-010 | AC-031, AC-032 | 5 | Exception/exemption actor-versus-student and bulk tests |
| FR-011 | AC-033, AC-034 | 4, 5 | Saved DOT/configuration tests and runtime exclusion controls |
| FR-012 | AC-035, AC-036 | 5 | Persisted remix diffs and canceled edit controls |
| FR-013 | AC-037, AC-038 | 4 | Each destructive target and replacement/partial outcomes |
| FR-014 | AC-039, AC-040 | 6 | Self/moderator/thread deletion and safe identities |
| FR-015 | AC-041, AC-042 | 6 | Intervention old/new results and routine scoring exclusions |
| FR-016 | AC-043, AC-044 | 4 | Generic project key map and all setting families |
| FR-017 | AC-045, AC-046 | 4 | Defaults/bank/objective/curriculum revision tests |
| FR-018 | AC-047, AC-048 | 5 | All three types, lifecycle and remaining setting keys |
| FR-019 | AC-049, AC-050 | 6 | Invite/role/status/bulk enrollment attribution |
| FR-020 | AC-051, AC-052 | 5 | Manual/worker publication application and policy tests |
| FR-021 | AC-053, AC-054 | 5 | Conditions/index atomicity and bulk/clear schedules |
| FR-022 | AC-055 | 5, 6 | Configuration key coverage and composition |
| FR-023 | AC-056, AC-057 | 6 | Money/code/discount/entitlement privacy and rollback |
| FR-024 | AC-058, AC-059 | 6 | Certificate configuration/decision attribution and job separation |
| FR-025 | AC-060, AC-061, AC-062 | 3 | Organization/consent/integration typed scopes and secret exclusion |
| FR-026 | AC-063, AC-064, AC-065 | 3 | AI/credential/flag/rollout lifecycle and existing-event regressions |
| FR-027 | AC-066, AC-067 | 4, 6 | Actual confirmed import/repair/restore/admin results |
| FR-028 | AC-068 | 6 | Persisted preference diffs and login composition |
| FR-029 | AC-069, AC-070, AC-071 | 1, 2, 3, 4, 5, 6 | Original event ownership matrix plus retained regression tests |
| FR-030 | AC-072, AC-073, AC-074 | 1, 3, 5 | Marker secrets, deleted identities and historical sanitization |
| FR-031 | AC-075, AC-076, AC-077, AC-078 | 1 | Partition-boundary/provisioning/constraint/rehearsal evidence |
| FR-032 | AC-079, AC-080, AC-081, AC-082 | 1 | v1/v2 checks, bounded conversion, safe retirement/down/roll-forward |
| FR-033 | AC-083, AC-084, AC-085, AC-086 | 5 | Source provenance/collisions/redaction and effective-settings invariance |
| FR-034 | AC-087, AC-088, AC-089, AC-090 | 1, 7 | Search/filter/display/accessibility/pagination tests |
| FR-035 | AC-091, AC-092 | 2, 7 | Admin-only page and domain/tenant authorization; async replay authorization from PR-04 |
| FR-036 | AC-093, AC-094, AC-095 | 2 | Private topology compilation fixtures and caller bypass checks |
| FR-037 | AC-096, AC-097, AC-098 | 3, 4, 5, 6, 8 | Real directive paths and represented actors, no blanket bypass |
| FR-038 | AC-099, AC-100, AC-101 | 1, 2, 8 | Per-PR tests and combined revision-bound QA/approval |
| FR-039 | AC-102, AC-103 | 1, 6, 7, 8 | Write/query/recovery benchmarks and safe diagnostics |
| FR-040 | AC-104, AC-105 | 5, 6, 8 | Student answers/automatic scoring/no-op/cancel controls |

## Recommended first execution slice

Start with PR-01's detailed storage/contract design and early review of the complete event payload matrix and migration/recovery sequence, then implement that one PR. PR-02 proves the enforcement/orchestration architecture. Work through the four coverage PRs without planning further subdivisions. This plan does not authorize code, schema generation, commits or publication by itself.

The seven approved Jira sub-tasks exist as MER-6111 through MER-6117 (see the Implementation PRs table and `jira-subtasks.md`). Final publication/QA uses the existing integration route and explicit stage approvals.
