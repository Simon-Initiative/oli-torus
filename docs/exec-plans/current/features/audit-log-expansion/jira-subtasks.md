# MER-6066 - Jira Sub-tasks

Seven children, one per planned implementation PR, created on 2026-10-29 as MER-6111 through MER-6117 under MER-6066. The Jira descriptions are short summaries; the sections below remain the detailed scope. Four children cover the four coverage PRs; internal work areas do not become separate children. Only actual execution showing excessive size, followed by owner agreement, can change this packaging. There is no separate ClickHouse or settings-history child.

## Common creation envelope

- Project: MER. Type: Sub-task (verify live supported type/required fields before creation). Parent: MER-6066 — Audit Log Expansion.
- PR base: story/MER-6066-audit-log-expansion. Complete integration later targets master. Existing first-slice branch/worktree are reused.
- Assignee: the MER-6066 assignee. Sprint is inherited from the parent. Priority, estimates and release fields are unset. Initial status is the workflow default (Analyzing).
- Definition of done: corresponding plan phase's complete tasks, tests and gate plus the common slice contract; developer review and CI; one reviewed implementation PR into integration with a merge commit.
- Parent QA/acceptance is phase 8 in plan.md, not another implementation child. The plan and requirements paths below are repository-relative references, not fabricated Jira links.

## PR-01 (MER-6111) - Event contracts, partitioned storage, and central-history migration

Summary: Audit Log — Event contracts, partitioned storage, and central-history migration

Scope: Full event catalog, safe schema/validation and factory insert tests; partitions, historical central-data conversion, retirement and history-preserving rollback.

Dependencies: Reviewed storage/contract design.

Requirements: FR-001, FR-002, FR-029, FR-030, FR-031, FR-032, FR-034, FR-039. Criteria: AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-069, AC-070, AC-071, AC-072, AC-073, AC-074, AC-075, AC-076, AC-077, AC-078, AC-079, AC-080, AC-081, AC-082, AC-087, AC-088, AC-089, AC-090, AC-102, AC-103. Common invariants also apply.

Implementation:

- [ ] Before DDL, complete the field/action contract matrix from the domain changesets and the FDD catalog. Build valid and invalid factory-backed inserts for every admitted event, including future producer families, reset semantics, deleted subjects, bulk and async outcomes.
- [ ] Implement shared context/builders, conditional v1/v2 checks, safe snapshots, indexed partitioned storage and compatible readers. Adapt current producers only as needed to keep their existing events writing strict v2; do not silently accept new v1 rows or invent missing actors.
- [ ] Generate explicit up/down migrations; implement copy, validation, swap, same-deployment retirement, safe rollback archive and roll-forward. Primary path: one transactional migration with no `Oli.Release` change. Use the batched/resumable fallback with a guarded release sequence only if rehearsal at production volume requires it (see the PR-01 detailed design).
- [ ] Benchmark six-month versus annual partitions with stated volume assumptions; provision and test future partitions, missing-partition failure, privileges, diagnostics and both Oban configurations. Document maintenance, retirement and recovery gates.

Validation:

- [ ] Test every catalog case against PostgreSQL; reject invalid direct inserts; retain existing capture/read/producer assertions.
- [ ] Rehearse interruptions, redaction, historical nulls, composite lookups, sequence allocation, Jan/Jul boundaries, immediate rollback and rollback after new event types. Record locks, WAL, storage and elapsed time on an isolated database.
- [ ] Keep the existing Audit Log usable with new types before the final UI PR. Confirm the legacy source is retired only after readiness checks, in this PR and the eventual single deployment.
- [ ] Apply the common actor/privacy/authorization/atomicity/cardinality and supported-entry tests throughout the PR; update actual proof references.
- Existing regression command (only after isolated DB verification): `mix test test/oli/auditing_test.exs test/oli_web/live/admin/audit_log_live_test.exs test/oli/delivery/section_creation_test.exs`. Add the new audit tests for each internal block.

Completion gate:

- All contracts have real insert/reject tests; historical conversion, same-deployment retirement and safe rollback pass isolated rehearsal. Approve the concrete schema and maintenance procedure before implementation.

Risk: Large storage/migration scope; rehearse locking, copy/retirement and rollback, and justify partition interval with evidence.

Data impact: Partitioned central storage, historical conversion and safe same-deployment retirement/recovery.

Exclusions: no unrelated domain behavior, new unsupported endpoints, ordinary learning audit or automatic retention. Other coverage areas remain with their named PR owner. No additional pilot/split is planned.

References: `docs/exec-plans/current/features/audit-log-expansion/plan.md`, phase 1; `docs/exec-plans/current/features/audit-log-expansion/requirements.yml`; `docs/exec-plans/current/features/audit-log-expansion/coverage-inventory.md`.

## PR-02 (MER-6112) - Boundary and CI with audited user-deletion pilot

Summary: Audit Log — Boundary and CI with audited user-deletion pilot

Scope: Private raw mutations, shared audited coordination, a real user-deletion action, compiled Boundary enforcement and CI.

Dependencies: PR-01 (MER-6111) and transitive prerequisites.

Requirements: FR-003, FR-004, FR-007, FR-029, FR-035, FR-036. Criteria: AC-008, AC-009, AC-010, AC-011, AC-012, AC-013, AC-014, AC-022, AC-023, AC-024, AC-069, AC-070, AC-071, AC-091, AC-092, AC-093, AC-094, AC-095. Common invariants also apply.

Implementation:

- [ ] Install/configure Boundary and extract only the selected user-deletion mutation. Implement the actor-aware coordinator, historical identity capture and shared transaction; remove duplicate manual capture.
- [ ] Inventory compiler dependencies and exact legacy exceptions. Prove read-context, web and Scenario callers cannot statically call the private mutation; no broad outgoing/incoming-check disable.
- [ ] Add forced compilation with warnings as errors to relevant CI builds. Demonstrate per-operation replay serialization, including deletion after the target no longer exists, without a coordination table.

Validation:

- [ ] Prove real delete + event, authorization denial, mutation failure and injected audit failure rollback; concurrent retry emits one semantic success even across a partition boundary.
- [ ] Run allowed and intentionally forbidden compilation fixtures; document .exs/test-support checking limits and direct SQL/dynamic invocation limits.
- [ ] Apply the common actor/privacy/authorization/atomicity/cardinality and supported-entry tests throughout the PR; update actual proof references.
- Existing regression command (only after isolated DB verification): `mix test test/oli/accounts_test.exs test/oli_web/live/users`. Add the new audit tests for each internal block.

Completion gate:

- Compiled allowed/forbidden examples and real transaction/replay tests pass before broad Boundary replication.

Risk: Boundary topology must be compiled and proved; field-level/direct-SQL/dynamic bypasses need tests and inspection.

Data impact: Use the shared event model. No generic operation registry or new domain schema is assumed.

Exclusions: no unrelated domain behavior, new unsupported endpoints, ordinary learning audit or automatic retention. Other coverage areas remain with their named PR owner. No additional pilot/split is planned.

References: `docs/exec-plans/current/features/audit-log-expansion/plan.md`, phase 2; `docs/exec-plans/current/features/audit-log-expansion/requirements.yml`; `docs/exec-plans/current/features/audit-log-expansion/coverage-inventory.md`.

## PR-03 (MER-6113) - Coverage: identity and platform administration

Summary: Audit Log — Coverage: identity and platform administration

Scope: Accounts, profiles, access rights, authentication/recovery, organizations and consent configuration, LMS/SSO/LTI and external-tool/roster/grade-passback configuration, AI services, API/MCP credentials and feature flags/rollouts.

Dependencies: PR-02 (MER-6112) and transitive prerequisites.

Requirements: FR-006, FR-007, FR-025, FR-026, FR-029, FR-037. Criteria: AC-019, AC-020, AC-021, AC-022, AC-023, AC-024, AC-060, AC-061, AC-062, AC-063, AC-064, AC-065, AC-069, AC-070, AC-071, AC-096, AC-097, AC-098. Common invariants also apply.

Implementation:

- [ ] Extract protected access mutations and move existing role/internal-flag/delete capture into shared coordination without duplicates.
- [ ] Route generic updates of protected fields through the same policy. Compose collaborator invitation cleanup with author deletion without independently committing the inner action.
- [ ] Classify every generic account write by persisted field. Extract audited creation/profile/link operations while preserving provider, invitation and verification behavior.
- [ ] Make technical provisioning/Setup PW attribution explicit; subsequent represented actions retain their actual human actor. Migrate supported Scenario and provider entry points, including bootstrap helpers.
- [ ] Preserve domain validation and safe response shapes; do not serialize password/email-verification inputs as arbitrary audit details.
- [ ] Map every session entry point, including the lower-level create/install helpers and Playwright session setup, to one semantic issuance/revocation boundary.
- [ ] Compose account linking and necessary profile/preferences writes without recapturing login. Define token persistence versus cookie delivery and server-side revocation semantics.
- [ ] Audit recovery lifecycle without storing tokens or credential hashes; document authenticated replay behavior and secret-bearing response limits.
- [ ] Introduce typed organization scopes and migrate settings/association writers, including bulk community membership and publisher defaults.
- [ ] Audit research-consent configuration separately from an individual accepting consent or saving preferences.
- [ ] Map organization/platform/section configuration inputs and safe-field policies; never capture JWKS secrets, signed launches or external credentials.
- [ ] Coordinate registration/deployment and external-tool relationship changes, preserving existing provisioning and deep-link flows; compose with remix/publication operations without duplicates.
- [ ] Explicitly locate roster synchronization and grade-passback policy writers, distinguishing them from routine synchronization/reporting.
- [ ] Implement provider/configuration safe projections and credential lifecycle builders using stable non-secret IDs.
- [ ] Route admin and project credential callers with actor/owner separation; preserve one-time credential responses without putting their values or hashes into audit/replay data.
- [ ] Move existing capture ownership to shared audited coordinators while preserving the seven event names and typed scope.
- [ ] Keep atomic feature-group behavior and post-commit cache invalidation; update all helper callers rather than layering a second capture.
- [ ] Implement the account/access/provisioning and auth work first, then organization/integration/service/credential/flag configuration within this same PR. Do not turn these internal blocks into separate PRs.
- [ ] Use existing project/section interfaces for integrations and credential ownership. Later authoring/delivery PRs compose these already-audited policies; they are not prerequisites for creating new organization or credential audit commands. Preserve a protected-key ownership map across generic updates.
- [ ] Keep remaining account preferences in PR-06 to honor their lower priority. Necessary login-related preference writes retain behavior and are explicitly completed by that later coverage PR.

Validation:

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

Completion gate:

- All account/integration/configuration blocks are covered, including generic writes and secret-bearing/session paths; preserve later domain composition interfaces.

Risk: Large account/integration surface and secret-bearing inputs; shared generic updates and session boundaries need careful ownership.

Data impact: Use the shared event model. No generic operation registry or new domain schema is assumed.

Exclusions: no unrelated domain behavior, new unsupported endpoints, ordinary learning audit or automatic retention. Other coverage areas remain with their named PR owner. No additional pilot/split is planned.

References: `docs/exec-plans/current/features/audit-log-expansion/plan.md`, phase 3; `docs/exec-plans/current/features/audit-log-expansion/requirements.yml`; `docs/exec-plans/current/features/audit-log-expansion/coverage-inventory.md`.

## PR-04 (MER-6114) - Coverage: authoring, projects, imports, and repairs

Summary: Audit Log — Coverage: authoring, projects, imports, and repairs

Scope: Project lifecycle, duplication/import, publishing, ownership/collaborators, project settings, authoring defaults/banks/objectives/curriculum, destructive content/media changes, imports and repairs. Project/content DOT settings compose the shared policy owned with delivery configuration.

Dependencies: PR-03 (MER-6113) and transitive prerequisites.

Requirements: FR-005, FR-008, FR-011, FR-013, FR-016, FR-017, FR-027, FR-029, FR-037. Criteria: AC-015, AC-016, AC-017, AC-018, AC-025, AC-026, AC-027, AC-033, AC-034, AC-037, AC-038, AC-043, AC-044, AC-045, AC-046, AC-066, AC-067, AC-069, AC-070, AC-071, AC-096, AC-097, AC-098. Common invariants also apply.

Implementation:

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

Validation:

- [ ] Preserve create/duplicate/publish assertions and publication immutability; assert rollback, collaborator cleanup composition and original author attribution in Scenarios.
- [ ] Exercise each target kind plus bulk partial/failed inputs, deleted identity, nested delete cardinality and edit-lock rejection. Add API/MCP entry tests rather than testing only builders.
- [ ] Test full success, partial repair, failed result inside an ok tuple, crash between chunks and safe resume; assert no repeated target successes or secret source URLs.
- [ ] Test each admitted settings family and mixed-field updates; preserve publication/version behavior and exclude analytics/export cache URL updates.
- [ ] Verify defaults versus delivery overrides, nested objective deletion/attachment, bank rule changes, curriculum edits and failed lock checks. Include representative MCP and real Scenario coverage.
- [ ] Apply the common actor/privacy/authorization/atomicity/cardinality and supported-entry tests throughout the PR; update actual proof references.
- Existing regression command (only after isolated DB verification): `mix test test/oli/course_test.exs test/oli/publishing_test.exs test/oli/accounts/collaborator_test.exs test/oli_web/controllers/collaborator_controller_test.exs test/oli/editing/resource_editor_test.exs test/oli/editing/page_editor_test.exs test/oli_web/controllers/api/activity_bank_controller_test.exs test/oli/google_docs/import_test.exs test/oli/interop/ingest_test.exs test/oli/authoring/project_repair_test.exs test/oli/experiments/configuration_test.exs test/oli/activities/activity_registration_project_test.exs test/oli/editing/objective_editor_test.exs`. Add the new audit tests for each internal block.

Completion gate:

- Authoring semantics, imports and repairs are covered. Before relying on async auditing, prove retry/terminal capture/pruning and external reconciliation inside this PR; no separate ClickHouse gate PR.

Risk: Revision-based deletion, composed publishing and partially committed/external imports; async recovery must be proved with the actual workflows.

Data impact: Use the shared event model. No generic operation registry or new domain schema is assumed.

Exclusions: no unrelated domain behavior, new unsupported endpoints, ordinary learning audit or automatic retention. Other coverage areas remain with their named PR owner. No additional pilot/split is planned.

References: `docs/exec-plans/current/features/audit-log-expansion/plan.md`, phase 4; `docs/exec-plans/current/features/audit-log-expansion/requirements.yml`; `docs/exec-plans/current/features/audit-log-expansion/coverage-inventory.md`.

## PR-05 (MER-6115) - Coverage: delivery and configuration

Summary: Audit Log — Coverage: delivery and configuration

Scope: Assessment settings and settings_changes migration, student exceptions/exemptions, section/product/blueprint lifecycle and settings, DOT/activation/recommendation configuration, remixes, publication updates, gating and scheduling, discussion/notes/student-support configuration.

Dependencies: PR-04 (MER-6114) and transitive prerequisites.

Requirements: FR-009, FR-010, FR-011, FR-012, FR-018, FR-020, FR-021, FR-022, FR-029, FR-033, FR-037. Criteria: AC-028, AC-029, AC-030, AC-031, AC-032, AC-033, AC-034, AC-035, AC-036, AC-047, AC-048, AC-051, AC-052, AC-053, AC-054, AC-055, AC-069, AC-070, AC-071, AC-083, AC-084, AC-085, AC-086, AC-096, AC-097, AC-098. Common invariants also apply.

Implementation:

- [ ] Move single/bulk/reset writes into audited composition; derive diffs from locked persisted values and preserve secure-delivery/adaptive/already-started rules.
- [ ] Keep auto-submit changes in the transaction and cache invalidation after commit. Replace historical writes and test readers with central events.
- [ ] Migrate safe source rows with provenance/new IDs and explicit unknowns; sanitize password history, verify external consumers and rollback redaction, then retire settings_changes in this slice.
- [ ] Introduce the audited exception boundary and migrate direct and bulk callers, including Scenarios.
- [ ] Reuse setting-field policies; identify the instructor actor separately from the student subject and keep auto-submit consistency.
- [ ] Enumerate persisted DOT/activation keys at all three scopes, including revision content edits; migrate configuration writers and safe prompt projections.
- [ ] Audit toggles and saved instructor prompts through section coordination. Treat trigger-point invocation as an exclusion/control case: its API invokes runtime behavior, not a settings mutation.
- [ ] Audit the committed diff at Remix.save, preserving the existing transaction across hierarchy, materialization and external-tool deep-link mappings.
- [ ] Coordinate manual and worker publication updates with initiator/system attribution and replay semantics; audit auto-update policy changes independently.
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

Validation:

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

Completion gate:

- Assessment history is safely consolidated/retired, all delivery blocks pass, and existing integrations/authoring/job policies compose without duplicate events.

Risk: Bulk/default/exception semantics, historical secrets, shared section writes and background publication updates.

Data impact: settings_changes conversion and retirement with its migrated writers; preserve effective behavior and sanitize history.

Exclusions: no unrelated domain behavior, new unsupported endpoints, ordinary learning audit or automatic retention. Other coverage areas remain with their named PR owner. No additional pilot/split is planned.

References: `docs/exec-plans/current/features/audit-log-expansion/plan.md`, phase 5; `docs/exec-plans/current/features/audit-log-expansion/requirements.yml`; `docs/exec-plans/current/features/audit-log-expansion/coverage-inventory.md`.

## PR-06 (MER-6116) - Coverage: learner administration and administrative operations

Summary: Audit Log — Coverage: learner administration and administrative operations

Scope: Enrollment/invitations/instructor access, moderation/deletion, attempt/grade/progress interventions, payments/discounts/codes/manual entitlements, certificates, ClickHouse administrative outcomes and remaining persisted account preferences.

Dependencies: PR-05 (MER-6115) and transitive prerequisites.

Requirements: FR-005, FR-014, FR-015, FR-019, FR-022, FR-023, FR-024, FR-027, FR-028, FR-029, FR-039, FR-040. Criteria: AC-015, AC-016, AC-017, AC-018, AC-039, AC-040, AC-041, AC-042, AC-049, AC-050, AC-055, AC-056, AC-057, AC-058, AC-059, AC-066, AC-067, AC-068, AC-069, AC-070, AC-071, AC-102, AC-103, AC-104, AC-105. Common invariants also apply.

Implementation:

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

Validation:

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

Completion gate:

- Learner/admin/ClickHouse/preferences blocks pass, routine learning remains excluded and final job outcomes survive pruning.

Risk: Administrative writes overlap normal learning and external processing; distinguish real outcomes, actors/subjects and routine activity.

Data impact: Use the shared event model. No generic operation registry or new domain schema is assumed.

Exclusions: no unrelated domain behavior, new unsupported endpoints, ordinary learning audit or automatic retention. Other coverage areas remain with their named PR owner. No additional pilot/split is planned.

References: `docs/exec-plans/current/features/audit-log-expansion/plan.md`, phase 6; `docs/exec-plans/current/features/audit-log-expansion/requirements.yml`; `docs/exec-plans/current/features/audit-log-expansion/coverage-inventory.md`.

## PR-07 (MER-6117) - Audit Log UI and search

Summary: Audit Log — Audit Log UI and search

Scope: Human-readable new and historical events; actor/entity/action/date/project/section search, deleted identities, safe details, administrator-only access and measured paging/query performance.

Dependencies: PR-06 (MER-6116) and transitive prerequisites.

Requirements: FR-034, FR-035, FR-039. Criteria: AC-087, AC-088, AC-089, AC-090, AC-091, AC-092, AC-102, AC-103. Common invariants also apply.

Implementation:

- [ ] Implement the approved investigation filters and safe snapshot-based text search with current-identity compatibility, UTC bounds, parameter validation and stable paging.
- [ ] Render actor/affected subject, multi-field changes, settings history, deleted/system/unknown identities and confirmed async outcomes. Keep admin-only authorization and avoid exposing schema plumbing.
- [ ] Benchmark actual predicates/indexes over representative multi-partition history; fix measured query costs and validate keyboard/labels/details behavior.

Validation:

- [ ] Test every event family rendering, deleted-name search, legacy data, empty/deep pages, equal timestamps, time boundaries and unauthorized requests.
- [ ] Verify query plans/partition pruning, bounded page size and no secret search indexing; conduct manual administrator investigation on the integrated preview.
- [ ] Apply the common actor/privacy/authorization/atomicity/cardinality and supported-entry tests throughout the PR; update actual proof references.
- Existing regression command (only after isolated DB verification): `mix test test/oli/auditing_test.exs test/oli_web/live/admin/audit_log_live_test.exs`. Add the new audit tests for each internal block.

Completion gate:

- Every coverage PR is integrated; readable/searchable history, deleted identities, authorization and measured query behavior pass.

Risk: Historical search, deleted identities, pagination counts and all-history query cost.

Data impact: Use the shared event model. No generic operation registry or new domain schema is assumed.

Exclusions: no unrelated domain behavior, new unsupported endpoints, ordinary learning audit or automatic retention. Other coverage areas remain with their named PR owner. No additional pilot/split is planned.

References: `docs/exec-plans/current/features/audit-log-expansion/plan.md`, phase 7; `docs/exec-plans/current/features/audit-log-expansion/requirements.yml`; `docs/exec-plans/current/features/audit-log-expansion/coverage-inventory.md`.

