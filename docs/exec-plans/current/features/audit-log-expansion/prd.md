# Audit Log Expansion - Product Requirements Document

## 1. Overview

Expand the central Torus Audit Log so an authorized administrator can establish who changed what, when, and which account, project, section, or resource was affected. Cover authentication, configuration, administrative interventions, and destructive operations across supported entry points while excluding routine learning activity.

Source of truth: [MER-6066](https://eliterate.atlassian.net/browse/MER-6066), checked on 2026-10-28, and the engineering agreements in `docs/exec-plans/current/features/audit-log-expansion/informal.md`. The work-item owner approved proceeding to architecture, explicitly confirming the search dimensions, existing administrator-only access, and no-op/cancellation/authentication-failure scope below. Traceability statuses describe document coverage, not implemented or accepted behavior; no implementation evidence is claimed.

## 2. Background & Problem Statement

The current `audit_log_events` table and `Oli.Auditing` support 16 event types. Producers have inconsistent transaction and error-handling behavior, and many requested actions have no central event. Search depends on current account/project/section records, which limits investigation after deletion. The existing administrator page is the intended investigation surface.

Assessment settings use a separate `settings_changes` history. Repository inspection found no product dependency on that history for effective settings or restoration; existing reads are test assertions. Some history includes password values. Consolidation must preserve useful evidence without copying secrets or maintaining two permanent histories.

Expanded coverage increases storage and query demands. Partitioned PostgreSQL storage must make future age-based retention practical and preserve existing records during conversion. Partitioning alone does not establish a retention policy or guarantee faster searches.

## 3. Goals & Non-Goals

### Goals

- Make administrative changes and authentication events attributable, understandable, and discoverable, including deleted targets and asynchronous outcomes.
- Cover the entire ticket, prioritizing access, destructive operations, and the highest-priority families before persisted preferences.
- Validate the full event vocabulary before broad instrumentation, and prove shared orchestration and static dependency enforcement with an early vertical implementation.
- Preserve existing audit coverage and replace the separate assessment-settings history with central visibility.
- Migrate to maintainable partitioned storage with an explicit cutover, historical-data policy, and rollback procedure.
- Deliver seven tested implementation PRs into the existing integration branch, with combined acceptance before merging to `master`.

### Non-Goals

- Auditing routine page visits, student answers, or automatic scoring; duplicating the learning analytics stream.
- Building a separate audit application, public audit API, export feature, or change-reversal UI.
- Introducing new business operations or transport endpoints solely to give every action an entry in every channel.
- Automatic historical deletion, a new production retention duration, tamper-proof archival, or a compliance-certification project.
- Adopting Carbonite, a runtime process-context monitor, or an unrelated repository-wide context reorganization.

## 4. Users & Use Cases

- **System administrator:** investigate an account/permission change, identify who deleted material, or distinguish an accepted repair from a completed repair.
- **Instructor:** perform existing settings, exception, enrollment, grading, and moderation operations with reliable attribution. This work does not grant instructors access to the administrator Audit Log.
- **Author:** perform existing project, publication, collaborator, configuration, and destructive editing operations with reliable attribution.
- **Affected learner/account holder:** remain distinguishable from the person performing an intervention; ordinary learning behavior stays outside this expansion.
- **Developer, QA, and operator:** verify coverage across channels, prevent accidental unaudited callers, exercise realistic Scenarios, and operate the migration and partition lifecycle.

## 5. UX / UI Requirements

Extend `/admin/audit_log` using its established table, details, pagination, and filter patterns. Present human-readable actions, actor and affected subject separately, scope, time, meaningful safe changes, and asynchronous state where applicable. System identity, unknown historical data, and unavailable/deleted targets must be recognizable without broken links or invented information.

The owner-approved minimum investigation contract includes search by retained actor and affected-entity identity, action selection, time range, and relevant project/section scope. Existing name/email/slug searches must remain useful; snapshots must allow searching deleted entities. This interprets Jira's broad “searchable” requirement without adding arbitrary full-text search over all payload JSON. Exact controls and layout belong to design.

Preserve keyboard operation, accessible labels, focus behavior for details, and established localization/time-display conventions. Do not expose raw secrets or technical schema-version details as primary UI content. Complete the comprehensive UI/search work after coverage PRs, while keeping the existing page functional throughout integration.

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)

Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- **Reliability:** local database mutations and their audit evidence have a shared commit/rollback outcome. External and asynchronous work needs explicit lifecycle handling; a database transaction alone does not guarantee external atomicity.
- **Security/privacy:** preserve operation authorization and administrator-only audit access. Use event-specific safe fields, including nested values and historical conversion, instead of serializing arbitrary inputs or structs. Retain only the identity needed to interpret history.
- **Performance:** benchmark representative writes, bulk operations, and searches against the existing implementation, using a documented dataset and conditions. Measure added latency, query work, storage growth, and migration impact. Establish acceptable budgets in architecture review before final acceptance; no production volume or numeric SLA has been established by this analysis.
- **Maintainability:** share orchestration across channels, keep raw domain mutations separate from event creation, and use static dependency checks plus behavioral tests. Static checks are not a universal runtime guarantee.
- **Operability:** provision future partitions, make failed writes/maintenance diagnosable without payload leakage, and document recovery/cutover/rollback. Avoid accidental retention deletion or silent event loss.

## 9. Data, Interfaces & Dependencies

The event contract needs actor identity, affected entity/person, relevant scope, action, time, safe before/after values, historical identity, and operation/source/outcome context where applicable. Final columns, JSON structure, event names, indexes, and row cardinality belong to the FDD. Bulk evidence must identify every changed target; one SQL statement is not necessarily one semantic event.

Preserve an explicit `schema_version`: version 1 represents migrated incomplete historical formats; normal new events use version 2 and event-specific validation. Unknown historical values remain unknown. New producers cannot evade validation by requesting the legacy format. Apply detailed application validation and essential conditional database constraints.

Reuse `lib/oli/auditing.ex`, `lib/oli/auditing/log_event.ex`, the administrator LiveView/table, and existing transactional section-creation auditing where appropriate. Assess both central-history and assessment-history migrations separately. `settings_changes` source IDs require provenance and collision-safe mapping, not blind reuse as central event IDs.

Consumers include LiveViews/controllers, APIs, MCP, bulk operations, jobs/tasks, and `Oli.Scenarios`. Final interface signatures and authorization placement require architecture review. Receiving an actor for attribution is not permission to execute an operation.

## 10. Repository & Platform Considerations

Follow `AGENTS.md`, `ARCHITECTURE.md`, `docs/BACKEND.md`, `docs/FRONTEND.md`, `docs/TESTING.md`, and `docs/CODEREVIEW.md`. Use Phoenix/Ecto/PostgreSQL and established application boundaries. Keep domain coordination independent of the web transport. Preserve publication/resource versioning, tenant scoping, and existing operation behavior.

The agreed direction separates queries, internal mutations, and public audited coordinators, illustrated by `Oli.Accounts`, `Oli.Accounts.Mutations`, and `Oli.Accounts.Audited`. Boundary is the preferred static dependency guard; its topology, test coverage, and restrictions must be proved in the pilot before replication. Module naming by itself is not enforcement.

The owner selected Oban plus central audit events for asynchronous execution and durable outcome history. Do not introduce a generic operation registry/table in the base design. Synchronous actions use their mutation + audit transaction; correlation IDs remain event/job metadata. Preserve retry and outcome requirements through per-action idempotency and durable terminal capture that survives job pruning. Additional coordination storage requires a demonstrated gap after evaluating existing domain records; no such necessity has yet been established for this ticket.

Generate migrations with `mix ecto.gen.migration` and explicit `up/0` and `down/0`. Run Mix commands with the permissions required by `AGENTS.md`. Verify isolated database configuration before tests or migration rehearsals; do not reset or migrate the shared database during analysis. Use `run-server` on port 4000 when a server is required later.

Traceability uses the nested FR/AC format. The work-item validator checks structure and evidence file existence only; coverage is assessed by the implementing agent and the final reviewer.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item

Existing feature-flag and rollout actions are audited subjects, not a new opt-out switch for this feature. The proposed rollout uses the normal deployment process after the complete integration is accepted.

Reuse `MER-6066-audit-log-expansion` and `story/MER-6066-audit-log-expansion`. Implementation PRs target integration, receive developer review/checks, and merge with merge commits. The completed integration PR targets `master`, receives QA on its current preview revision, and enters the merge queue. Production release follows the repository's normal release process; merging an intermediate implementation PR is not an independent production rollout.

The owner selected seven implementation PRs: event contracts/storage and central-history migration; Boundary/CI with a first action pilot; four coverage PRs; and final UI/search. Assessment-history consolidation belongs with assessment settings in the delivery coverage PR. There is no separate ClickHouse pilot or settings-history PR. Keep the four coverage groups intact; only if execution shows that a PR is too large will the owner and engineer consider splitting it. Estimates or internal work areas do not authorize extra PRs. Tests belong to each PR. Prepare one subtask draft per implementation PR; concrete Jira creation and publication require the user's confirmation.

The storage cutover must preserve safe historical contents and post-cutover events. The FDD must resolve locking, simultaneous writes, application-version overlap, sequence/identity behavior, partition provisioning, and rollback. A temporary integration-only adapter requires an explicit removal gate; there is no standing allowance for new version-1 production writes. Six-month and annual partition intervals remain candidates, with the decision justified by evidence.

Use the owner-supplied [Safe Ecto Migrations guidance](https://github.com/fly-apps/safe-ecto-migrations) when designing execution. Separate preparation, resumable data copying, validation, short cutover, and retirement; these are migration phases within the reviewed release, not a change to the integration-branch delivery agreement. The FDD records the concrete safeguards and PostgreSQL-specific caveats.

The owner requires the superseded central audit table to be removed in the same implementation PR and deployment as its replacement, after verification and recovery-readiness checks. Do not defer that retirement to a later cleanup PR/release. Failed checks stop or roll back the deployment; they do not authorize unsafe deletion.

## 12. Telemetry & Success Metrics

Use existing operational logging/APM where applicable to observe audit failures, added latency, asynchronous completion, and partition-maintenance failures. Do not duplicate event payloads or secrets into telemetry. This is targeted operational evidence, not a new analytics dashboard or instrumentation framework.

Completion is measured by traceable coverage of every in-scope action/channel, passing atomicity/failure/no-duplicate tests, reconciled historical migration results with explicit redactions, and successful administrator investigation of representative new and historical events. Performance acceptance uses the reviewed benchmark budgets. Zero errors in a small test run is not proof of production-scale completeness.

## 13. Risks & Mitigations

- **Broad scope hides alternate paths:** inventory actions and channels, including generic updates, direct database calls, bulk paths, jobs, and existing manual captures; map each to tests and a planned PR.
- **A generic schema fails on complex actions:** validate full event contracts early with insert cases for actor-versus-subject, deletion, settings resets, bulk operations, and asynchronous outcomes.
- **Static checks give false confidence:** prove allowed and forbidden dependencies; explicitly inspect bypasses and verify transaction behavior separately.
- **Migration loses or fabricates history:** preserve reliable source data, retain provenance, keep unknowns explicit, redact secrets, and rehearse cutover/rollback on an isolated database.
- **Existing settings history contains secrets:** replace plaintext assertions and sanitize backfill while retaining evidence that a setting changed.
- **Audit failure changes application availability:** enforce local atomicity and make errors diagnosable; design external/session workflows and retries explicitly instead of assuming local rollback covers them.
- **Write/query overhead or missing partitions:** benchmark representative workloads and define partition provisioning/recovery before release.
- **Large first PR delays feedback:** preserve early review of the full model and migration, using internal contract/storage/migration review checkpoints. Keep the agreed packaging; coverage splits require execution evidence and owner agreement.

## 14. Open Questions & Assumptions

### Open Questions

- Does the technical review identify any issue with the shared-coordinator interpretation of the ticket's invocation example? Search dimensions and access scope were explicitly confirmed by the work-item owner.
- Which existing action paths require external/session-specific failure handling, partial-outcome reporting, and retry reconciliation? The FDD must define these without treating initiation as success.
- What physical schema, safe snapshot fields, change representation, and event cardinality best cover the catalog? How are system/bootstrap actors and source context represented?
- What partition interval, provisioning mechanism, indexes, migration/cutover procedure, and measurable performance budgets fit actual deployment constraints?
- Are there external consumers of `settings_changes` beyond the repository? Confirm any known consumers before retiring the table.
- Which concrete Boundary topology and test arrangements restrict raw mutation access without broad exemptions? How will remaining direct-write paths be inventoried and reviewed?

### Assumptions

- All highest-priority and additional ticket categories remain in scope; prioritization controls implementation order, not silent deferral.
- Common event requirements apply to every action family. A family-specific criterion does not waive actor, privacy, authorization, atomicity, channel, or historical requirements.
- Ordinary no-op saves do not produce successful-change events. Lifecycle actions such as login, logout, or requesting an administrative job may be meaningful without a configuration diff.
- Failed authentication attempts are not newly mandated as a separate event family; they must never be recorded as successful logins. Asynchronous administrative failure outcomes are explicitly in scope.
- Existing administrator access is retained. No new instructor/author history screen or permissions are assumed.
- Historical evidence must not be fabricated to satisfy the new schema. Missing source data is an explicit limitation, not an implementation failure to conceal.

## 15. QA Plan

Automated verification starts with event-contract inserts and rejects, conditional database constraints, migration/rollback rehearsals, and partition-boundary cases. The pilot then proves static violations fail CI and that audit-write failure rolls back the local domain mutation. Each coverage PR tests supported entry points, correct attribution and values, no-ops/failures, duplicates, and relevant bulk/job/retry behavior.

Use factories for isolated contract tests and unrelated setup. Public behavior tests use audited application operations; narrowly scoped internal tests may exercise raw mutations. Use real directives/application paths for `Oli.Scenarios`, including Playwright setup. Verify technical bootstrap attribution, subsequent author/instructor attribution, and exclusion of ordinary student answers.

Retain and extend existing audit, account, publishing, section-creation, flag/rollout, Google Doc import, attempt-deletion, ClickHouse, and settings tests. Validate old/new event rendering and search, deleted identities, unauthorized access, keyboard interactions, and stable pagination. Benchmark writes and queries with reproducible inputs; do not use the shared development database for destructive rehearsals.

Manual acceptance on the final integration preview should trace representative authentication, student exception, bulk settings/reset, deleted content/account, and asynchronous administrative operations from action to searchable evidence. Check migrated settings and incomplete legacy rows. Record the tested head revision and repeat affected acceptance after fixes or syncs. Follow repository security, performance, requirements, and applicable implementation/UI review guidance.

## 16. Definition of Done

- [x] PRD follows the required section structure and distinguishes proposals, assumptions, and unresolved architecture decisions.
- [x] Detailed requirements and criteria are captured in `requirements.yml`; no implementation evidence is invented.
- [x] Required PRD/requirements validators and supplementary nested-format checks pass.
- [x] The work-item owner accepted proceeding to architecture and explicitly confirmed search dimensions, administrator-only access, and no-op/cancellation/authentication-failure scope. Technical design and implementation planning still require their own review.
- [ ] Feature completion is established later through FDD/plan traceability, implementation evidence for all criteria, migration/performance validation, and QA of the complete integration.
