# Audit Log Expansion — Informal Input

## Purpose and status

This document records the scope, code findings, and engineering agreements for [MER-6066 — Audit Log Expansion](https://eliterate.atlassian.net/browse/MER-6066). It is the input to Harness analysis, architecture, and planning, not an approved PRD, final database design, or implementation plan.

Jira remains the source of truth for product scope and acceptance criteria. The ticket was checked on 2026-10-28. Repository findings refer to the initial checkout at `237980b77c`; refresh relevant evidence during formal design. Decisions below reflect the engineering discussion. Recommendations and unresolved design questions are identified separately so they are not silently promoted into requirements.

The main planning objective is early feedback: validate the complete event data model first, then prove the orchestration and enforcement approach with a small vertical implementation before expanding it across Torus. Each PR should be independently reviewable and tested, while the complete feature reaches `master` together through the integration branch.

## Product scope

Make it possible to determine who performed an administrative or configuration action, what changed, when it happened, and which entity and scope were affected. Distinguish the actor from the affected person. Preserve enough historical identity to understand events after entities are deleted.

### Highest-priority actions from Jira

- User and author login/logout through password, SSO/OAuth, and LTI, including forced session revocation.
- Account creation/deletion, profile edits, locking/unlocking, roles, permissions, section-creation rights, account linking, and credential recovery.
- Project creation, duplication/import, deletion, publication, ownership, and collaborators.
- Instructor assessment settings, including individual edits, bulk edits, and resets to defaults.
- Student assessment exceptions and exemptions: create, modify, delete, and bulk operations.
- DOT and activation-point settings at project, section, and content scope, including prompts and instructor AI recommendations.
- Saved section remixes: material additions/removals, moves/reordering, visibility, and source publication changes.
- Destructive authoring: removing pages/containers and embedded activities, deleting bank questions or media, and imports/repairs that replace content.
- Discussion post/thread deletion and moderation by the author, instructor, or administrator.
- Interventions in learner records: deleting/resetting attempts, restoring progress, manual grade changes, and regrading.

### Additional actions from Jira

- Remaining project settings: visibility, duplication permissions, learning models, experiments, alternatives, activity/tool availability, and required surveys.
- Authoring configuration: assessment defaults, bank rules, objectives, and curriculum settings.
- Section/product/blueprint creation, deletion, archival, schedules, access, registration, delivery, and required surveys.
- Enrollment and instructor access: invitations, roles, suspension, and unenrollment.
- Publication updates applied to sections and automatic-update policies.
- Gating, prerequisites, and bulk curriculum scheduling.
- Discussion, notes, certificate, and student-support configuration.
- Paywall/payment settings, pricing, discounts, payment codes, and manual entitlements.
- Certificate configuration and administrative grants/revocations.
- Institution, community/publisher, research-consent, LMS/SSO/LTI, external-tool, roster, and grade-passback configuration.
- AI model/service configuration, API/MCP credential lifecycle, feature flags, and rollouts.
- Administrative imports, repairs, deletion/restoration, and other operations replacing or removing data.
- Persisted user/author preferences, after access-related and destructive actions.

Routine learning activity is excluded: page visits, quiz submissions, and automatic scoring are not new administrative audit events. Administrative actions affecting those records remain in scope. Previewing or canceling an unsaved edit must not appear as a committed change.

### Cross-cutting acceptance

- Cover every supported entry point for an in-scope action: UI, API, MCP, bulk operations, and background work. Do not create endpoints that do not otherwise exist merely to satisfy a channel checklist.
- Keep event creation separate from the mutation being instrumented, while coordinating their persistence transactionally where applicable.
- Record meaningful before/after values, without passwords, tokens, credentials, or other secrets.
- Avoid duplicate events and false successful events for failed or canceled operations. Persist outcomes for asynchronous administrative work.
- Preserve existing audit coverage and integrate assessment-settings history into the central Audit Log.
- Make the new events understandable and searchable in the existing Audit Log.
- Introduce PostgreSQL partitioned storage and migrate existing audit data. Investigate and justify partition granularity; the ticket suggests six-month or annual intervals.

## Existing implementation and reusable infrastructure

### Central storage and writes

`lib/oli/auditing/log_event.ex` maps to `audit_log_events`. The physical columns are:

| Column | Current role |
| --- | --- |
| `id` | Generated primary key |
| `user_id`, `author_id` | Acting account references |
| `event_type` | String in PostgreSQL, `Ecto.Enum` in the schema |
| `section_id`, `project_id`, `resource_id` | Context/resource references |
| `details` | JSON/map payload, defaulting to an empty map |
| `inserted_at` | Event timestamp; there is no `updated_at` |

`actor`, `resource`, and `total_count` are virtual schema fields. The original migration, `priv/repo/migrations/20250819181513_create_audit_log_events.exs`, uses integer references without foreign keys and separate indexes for actor IDs, project/section IDs, event type, and timestamp.

`lib/oli/auditing.ex` supplies `capture/4`, `capture!/4`, listing, lookup, browsing, and display-data loading. It maps users/authors to actor IDs and projects/sections to their respective IDs. Other struct IDs are put into `resource_id`, with a resource-type detail. This generic mapping must be reviewed when introducing an explicit affected-entity contract; an arbitrary struct ID is not necessarily a resource-table ID.

The current changeset requires an event type and at least one actor ID. Although `capture/4` documentation mentions a nil system actor, the schema's allowed system-event list is empty. Explicit system identity therefore needs implementation, not just a new calling convention. The current payload has no event-specific secret allowlist or complete before/after contract.

There are 16 existing event types:

```text
user_deleted                       author_deleted
author_role_changed                project_published
section_created                    feature_flag_enabled
feature_flag_disabled              feature_flag_removed
google_doc_imported                feature_rollout_stage_changed
feature_rollout_stage_deleted       feature_rollout_exemption_upserted
feature_rollout_exemption_deleted   account_internal_flag_changed
clickhouse_admin_operation_initiated resource_attempt_deleted
```

Preserve the behavior and meaning of all existing coverage while tightening guarantees. Existing write paths vary: some audit within a transaction, some after the mutation, and some log or ignore audit failures. A wrapper that calls an already-audited function can produce duplicates unless the original capture is deliberately relocated.

Useful implementation and test anchors include:

- `lib/oli/accounts.ex` and the user/author detail LiveViews: account changes, deletion, and role changes.
- `lib/oli/publishing.ex`: publishing and its transaction boundaries.
- `lib/oli/delivery.ex`, `lib/oli/delivery/section_creation_auditor.ex`, and `test/oli/delivery/section_creation_test.exs`: an existing transactional audit sink and rollback coverage worth reusing.
- `lib/oli/scoped_feature_flags.ex` and `lib/oli/scoped_feature_flags/rollouts.ex`: flags and rollout events.
- `lib/oli/google_docs/import.ex`: import events and audit error handling.
- `lib/oli/delivery/attempts/core.ex`: attempt deletion and capture placement.
- `lib/oli/clickhouse/admin_operations.ex`: an initiation event preceding asynchronous work; initiation is not proof of successful completion.
- `test/oli/auditing_test.exs`, `test/oli/accounts_test.exs`, `test/oli/scoped_feature_flags/audit_integration_test.exs`, `test/oli/google_docs/import_test.exs`, and `test/oli/clickhouse/admin_operations_test.exs`: starting regression coverage, not proof that every acceptance criterion is already tested.

### Queries and existing UI

There is already an administrator LiveView at `/admin/audit_log`: `lib/oli_web/live/admin/audit_log_live.ex`, with `lib/oli_web/live/admin/audit_log/table_model.ex`. Reuse its authorization, table, pagination, sorting, filters, and details presentation where suitable. Its tests are in `test/oli_web/live/admin/audit_log_live_test.exs`.

The current browsing query in `lib/oli/auditing.ex` searches joined user/author names and emails and project/section slugs. It does not search arbitrary details or immutable entity snapshots. Consequently, live joins alone cannot provide historical search after deletion. `lib/oli/auditing/browse_options.ex` declares date/project/section options that the current browsing query does not implement.

The ticket requires improvements to this existing surface, not a separate audit application. Define the required search behavior explicitly in the PRD; do not assume that adding enum values makes new event payloads searchable.

### Entry-point discovery still required

Formal planning must produce an action-by-entry-point inventory, not just a list of contexts. Existing anchors include `lib/oli_web/user_auth.ex`, `lib/oli_web/author_auth.ex`, authentication/launch controllers, `lib/oli_web/controllers/api/`, `lib/oli/mcp/`, section-settings/remix LiveViews, authoring repair/import flows, grading/progress administration, and background workers/tasks.

For example, `lib/oli/mcp/tools/create_activity_tool.ex` invokes application behavior separately from LiveViews; MCP usage tracking is not a substitute for the required semantic audit event. `lib/oli/mcp/auth.ex` also contains credential lifecycle operations. Inspect equivalent alternate paths for every action, including generic updates, direct `Repo` calls, and bulk writes.

## Agreed application architecture

### Three distinct responsibilities

Use domain-specific shared orchestration so every transport invokes the same audited application operation. The Accounts naming discussed is illustrative:

| Module | Responsibility |
| --- | --- |
| `Oli.Accounts` | Public read/query functions for the migrated area |
| `Oli.Accounts.Mutations` | Internal create/update/delete behavior, without audit-event creation |
| `Oli.Accounts.Audited` | Public orchestration: receive actor/context, invoke the mutation, build the event, and coordinate persistence |
| `Oli.Auditing` | Shared event validation, storage, and querying infrastructure |

The intended call path is `UI/API/MCP/job/Scenario → Accounts.Audited → Accounts.Mutations + Oli.Auditing`. The coordinator is an application service, not a LiveView helper. Do not move domain orchestration into a single giant global auditing module.

This is the agreed interpretation of the ticket's point-of-invocation example: the shared coordinator invokes the pure mutation and audit write. Validate this interpretation in the early architecture review. Merely adding an actor argument and an audit insert inside the existing raw `delete_user` function would not achieve the agreed separation.

Apply the separation incrementally to in-scope operations. Classify functions by effects, not by their names. Do not require an unrelated repository-wide context reorganization before proving the approach. As an operation migrates, remove or restrict its old unaudited public entry point; leaving a forwarding shortcut to the raw mutation defeats the intended contract.

### Atomicity and event meaning

- For local database mutations, coordinate the mutation and event in the same database transaction, using existing transaction infrastructure or `Ecto.Multi` as appropriate. Both must roll back if either fails. Ensure error results actually trigger rollback rather than merely returning an error tuple from a transaction callback.
- Determine before values from authoritative persisted state and after values from the mutation result inside the transaction; both the change and its event become durable only on commit. Design concurrency control where needed; stale UI state is not sufficient evidence of what changed.
- Preserve existing authorization and domain invariants. Receiving an actor for attribution must not implicitly grant permissions.
- Compose nested audited operations deliberately. Decide which layer owns each semantic event so internal calls do not duplicate it. One user operation may legitimately affect multiple entities; define that event cardinality rather than assuming one row per SQL write or one row per request.
- Record only meaningful changes. Specify treatment of no-ops and resets that leave the effective value unchanged. Cancellations and rejected operations cannot emit a successful-change event.
- Authentication/session actions need semantic instrumentation even when they are not ordinary context CUD functions. Define successful login/logout/revocation at the correct session boundary.
- A PostgreSQL transaction cannot undo external effects, browser cookies, or work on another database. Define initiation, completion, failure/cancellation, correlation, and retries for asynchronous or external operations. Preserve the initiating actor across job/process boundaries. Distinguish accepted work from completed work and handle partial outcomes explicitly.

### Oban and operation correlation

Owner decision: use Oban plus the central Audit Log for asynchronous work; do not add a generic `audit_operations` table or operation registry to the base design. Simple synchronous actions use the mutation + audit transaction without a job or extra coordination record. Keep `operation_id` as correlation metadata; it does not require a corresponding table.

For asynchronous work, atomically persist initiation and enqueue the job. Oban manages execution state and retries; central events preserve confirmed outcomes after jobs are pruned. Local worker mutations and their success events commit together. A failed attempt that will be retried is not a definitive operation failure. Define safe replay and durable final failure/cancellation capture, including crashes and pruning; Oban alone does not guarantee exactly-once effects or audit delivery.

Only reconsider additional coordination storage for a demonstrated gap: for example, aggregate progress across multiple jobs, uncertain external effects requiring recovery state, or replay guarantees beyond the available evidence. First inspect existing domain records. No concrete MER-6066 action has yet established that a new table is necessary; being asynchronous alone is not enough. Detailed design must resolve these cases before claiming complete retry/outcome guarantees, without preemptively adding infrastructure to every command.

### Boundary and CI

Use Boundary as the preferred static guard. It constrains module dependencies, not selected functions inside a mixed module. The exact boundary topology remains an architecture/pilot decision: nested boundaries and same-boundary access must be checked before claiming that only `Audited` can call `Mutations`. [Boundary documentation](https://boundary.hexdocs.pm/Boundary.html)

Integrate its compiler, inventory reported violations, migrate callers, and make forbidden references fail CI with warnings treated as errors. `mix compile` reports violations with locations; a forced compilation can support a complete initial inventory. Verify the final command and environments in the pilot. [Compiler documentation](https://boundary.hexdocs.pm/Mix.Tasks.Compile.Boundary.html)

The pilot must demonstrate an allowed read, an allowed audited mutation, and a rejected direct mutation call from representative consumers. Do not give all of `Oli`, `OliWeb`, or Scenarios unrestricted mutation access merely to silence warnings. Verify how tests and test support are compiled instead of assuming `.exs` files receive identical checks.

Boundary does not prove that an event was inserted or that its payload is correct. Dynamic invocation and direct database writes need explicit inspection; this is not runtime enforcement against every possible bypass. Transaction and behavior tests provide complementary evidence. If the pilot exposes a material enforcement gap, review it before expanding the pattern.

Carbonite is not part of the selected approach. Its trigger-based row capture addresses a different enforcement layer and would not remove the need for semantic actors/actions, selective coverage, and outcome handling. No unmeasured performance claim is a basis for rejecting it. A process-local audit-context monitor was discussed as an alternative diagnostic, but is also not an agreed implementation requirement.

## Data model and validation agreements

### Validate the whole event vocabulary early

Before broad instrumentation, define a catalog covering every action family in Jira and every existing event. For each concrete event, specify its actor, affected entity/person, scopes, action, timestamp, meaningful changes, allowed metadata, required/optional/not-applicable fields, and successful/failed/no-op behavior. Include single, bulk, and asynchronous variants where supported.

The first implementation PR should exercise those contracts with real insert tests using factory data. The intent is to discover that an exception, destructive action, bulk operation, or asynchronous outcome does not fit the model before migrating many contexts. These tests prove representability and validation; they do not substitute for subsequent tests of actual application entry points.

Use shared envelope validation and event-specific changesets/builders as appropriate. The agreement is explicit, testable contracts for all cases, not necessarily one separate duplicated changeset function per action.

### Required concepts; physical columns still to design

- Actor identity and kind, including an explicit system actor when appropriate. Keep the actor separate from an affected student/user/author.
- Affected entity type and stable identifier, with relevant project, section, account, institution, or other scope.
- Action/event type and timestamp. Decide whether recorded time and occurrence time need separate representation for asynchronous events and imported history.
- Minimal historical snapshots sufficient to identify actors and affected entities after deletion or renaming. Do not make continued readability depend on live foreign-key targets.
- Meaningful before/after changes and safe event-specific metadata.
- Source and operation correlation where needed to explain UI/API/MCP/jobs, bulk groups, retries, and outcomes.
- An explicit `schema_version` distinguishing historical format from the stricter new contract.

Column names such as `actor_type`, `entity_type`, `entity_id`, `actor_snapshot`, `entity_snapshot`, `changes`, `source`, and `operation_id` are illustrative, not approved DDL. The FDD must decide which concepts are indexed columns versus structured JSON, which existing columns remain, and how multiple affected entities/scopes are represented. Account linking, bulk changes, and deleted targets must fit without overloading unrelated IDs.

Avoid serializing whole structs, request parameters, changesets, authentication payloads, or unrestricted maps. Define safe fields per event, including nested data. Credential lifecycle events can describe creation/revocation or that a secret changed without recording its value. Historical preservation does not justify copying old secrets into the new store.

### Historical rows and new rows

Use `schema_version = 1` for migrated records whose original data cannot satisfy the new contract and `schema_version = 2` for the new event contract. Version identifies a format, not simply the date of the action; it is unrelated to content revisions or publication versions.

Preserve reliable existing IDs, timestamps, event meanings, scope references, and safe payloads. Populate new fields only from evidence already available. Leave genuinely unknown historical values null rather than inventing them. Current account names are not proof of event-time names; an absent actor is not automatically a system actor; an initiation record is not automatically a success record.

Apply validation at both levels:

- Ecto changesets/builders express the detailed event-specific contract and return useful errors.
- PostgreSQL constraints protect essential shared invariants and version-dependent requirements, including writes that bypass changesets. Required fields vary by event: a creation need not have a previous value, and an explicit system actor need not have a human account ID.

Do not backfill incomplete rows and then apply unconditional `NOT NULL` constraints to fields those same rows cannot provide. Use deliberate version-conditional constraints, with tests for SQL null behavior. Normal application entry points must not accept an arbitrary downgrade to the legacy version to evade validation. The exact migration-only insertion mechanism remains a design task.

### Integration-branch transition

All implementation PRs accumulate in the integration branch before the completed feature reaches `master`. We are not planning a production rollout where each incomplete PR is deployed independently.

Therefore, do not introduce a long-lived compatibility policy allowing new production events to use version 1 merely because producers are migrated in separate PRs. Keep `capture/4` only where it remains useful for existing callers; its presence does not require legacy-format writes.

The first storage PR must account for existing producers and readers so its tests and preview work. Prefer adapting the existing capture path and necessary existing call sites to valid new contracts. Do not manufacture missing actor/entity data in a generic adapter. If that makes PR 1 too large, the harness must propose a concrete, short-lived integration-only transition or a revised split, with an explicit removal gate before final integration. That is a review decision, not an already-approved fallback to new version-1 production writes.

Combining PRs into one release does not eliminate deployment ordering or old/new application overlap. The FDD must still specify the production cutover and rollback procedure.

## Partitioning and historical migration

Use native time-range partitioning as the design direction. A partitioned parent presents one logical table while rows reside in time-bounded children; removing an old partition can support future retention without deleting rows individually. Partitioning does not itself require extra audit columns; the richer event contract is a separate change. PostgreSQL also requires partition keys in parent-level unique/primary-key constraints. [PostgreSQL partitioning documentation](https://www.postgresql.org/docs/18/ddl-partitioning.html)

Six-month UTC calendar partitions are a candidate recommendation, not a final decision. Compare them with annual partitions using available volume/growth evidence, retention granularity, query patterns, maintenance cost, and migration constraints. Identify estimates and synthetic benchmarks as such; production measurements have not been established by this discovery. Do not claim partitioning automatically makes every audit query faster.

The FDD and first storage PR must address:

- Partition key, timezone, interval boundaries, oldest historical dates, and allocation of future partitions.
- How future partitions are created, who owns that maintenance, and behavior if a partition is missing. A fallback/default partition is a tradeoff to justify, not an assumed solution.
- Physical primary key and indexes, Ecto identity mapping, sequence handling after backfill, and compatibility with existing lookup-by-ID behavior.
- Search/pagination performance, date filtering, and evidence that relevant queries can avoid unnecessary partition scans.
- Backfill and cutover ordering, simultaneous writes, table locks, temporary storage/WAL requirements, and expected deployment impact. Choose a procedure appropriate to measured scale; do not promise zero downtime without evidence.
- Preservation checks for row counts, identifiers, timestamps, and safe contents; deterministic treatment of malformed or incomplete legacy records.
- A meaningful `down/0` and deployment rollback procedure, including events written after cutover. Do not describe discarding new events or reconstructing removed secrets as a valid rollback.

Creating partition infrastructure and documenting how future retention would work does not authorize deleting historical partitions or choosing a production retention period. Automated retention/deletion is outside the agreed implementation unless separately added to scope.

Owner decision: removal of the superseded central audit table belongs to the same PR as its replacement and must complete within the same deployment, after copy verification, reader/writer cutover, and recovery readiness checks. It is an ordered migration step, not cleanup deferred to another PR or release. If a safety check fails, stop/recover the deployment rather than dropping unverified data or treating retirement as optional follow-up. This does not combine the separate assessment-history implementation PR with the central-storage PR.

Later owner input: consider the [Safe Ecto Migrations guide](https://github.com/fly-apps/safe-ecto-migrations), including its migration-lock and backfilling documents. Apply its safety techniques in the FDD and migration plan while preserving explicit `up/0`/`down/0`, historical-data integrity, and the integration-branch delivery agreement. This reference does not itself decide whether production requires maintenance or an online transition.

## Assessment settings: replace the parallel history

The existing `settings_changes` table is a separate change history, not the source of effective assessment settings. Its schema in `lib/oli/delivery/settings/settings_changes.ex` has `resource_id`, `section_id`, actor `user_id`/`user_type`, a setting `key`, string `old_value`/`new_value`, and timestamps.

Repository inspection found writes in `lib/oli/delivery/settings/assessment_settings.ex` and `lib/oli_web/live/sections/assessment_settings/settings_table.ex`, through helpers in `lib/oli/delivery/settings.ex`. Reads found for this history are test assertions; no application consumer for restoring or calculating settings was found. Effective settings are resolved from domain state such as revisions, section resources, and student exceptions. This finding concerns repository consumers, not unknown external SQL consumers.

The individual update path already uses an `Ecto.Multi`; the bulk path has updates and history insertion that need a common atomicity review. Existing history can include assessment passwords, and tests currently assert those values. Preserve evidence that a password setting changed, but never migrate or continue recording its plaintext value.

Existing history assertions are in `test/oli_web/live/sections/assessment_settings/settings_live_test.exs` and `test/oli/delivery/sections/secure_delivery_settings_test.exs`. These are concrete migration targets, including assertions that currently count unchanged bulk fields or inspect password values.

The agreed direction is one central audit history:

1. Route future assessment edits, bulk edits, and resets through the audited application operation and central event contract.
2. Migrate useful, safe historical `settings_changes` data into the central store, preserving reliable actor mappings, scope, timestamps, and provenance. Do not infer operation grouping or typed old values when the source cannot support it.
3. Replace existing history assertions with central-audit assertions while preserving functional settings tests. Revisit tests expecting unchanged-field noise or plaintext secrets.
4. Remove obsolete history writers/readers and retire `settings_changes` after its dependencies and migration are accounted for.

Do not maintain permanent duplicate writes to both tables. Historical source tables may coexist during a controlled migration; this is different from maintaining two ongoing histories. Design source-row provenance/idempotence and ID allocation: IDs from this independent table cannot simply be reused as central audit IDs without considering collisions. Define rollback and safe retirement explicitly.

This work belongs to an implementation PR before the final UI/search PR. It is a separate backfill from the initial migration of `audit_log_events` itself.

## Tests, factories, Scenarios, and Playwright

### Tests belong in every PR

There is no later phase that retroactively supplies all tests. Each PR includes the checks needed for its contracts, changed behavior, and migration risks, and must pass before merging into integration.

- **First storage PR:** valid and invalid event insert cases across the full catalog; conditional database constraints; historical nullability; actor-versus-subject distinctions; safe snapshots; secret exclusion; representative bulk and async payloads. Include partition routing/boundaries, backfill preservation, sequence/lookup behavior, and rollback tests in an isolated database.
- **Boundary pilot:** prove allowed and forbidden dependency examples, CI failure for a violation, and actual success/failure atomicity through the public coordinator.
- **Every migrated action:** preserve domain behavior assertions; test exact relevant audit semantics on success, no false success on failure/cancellation, rollback on audit failure, and no duplicates. Exercise alternate supported entry points, bulk behavior, and retry/concurrency cases where applicable.
- **Assessment consolidation:** verify historical conversion/redaction, new central-only writes, single/bulk/reset behavior, and removal of legacy dependencies.
- **UI/search PR:** verify new and legacy event readability, deleted-entity identification/search, actor/subject distinction, pagination/filter behavior, system actors, authorization, and relevant query performance.
- **Final integration:** run the required regression suites and acceptance scenarios against the combined implementation and current integration preview.

Tests of public application behavior should use `Accounts.Audited` or its domain equivalent. Focused internal mutation tests may use `Mutations` through narrowly scoped test arrangements; the exact compilation/boundary mechanism must be verified in the pilot. Do not exempt all test-related application modules from architectural rules.

Factories remain appropriate for unrelated test setup and event-schema persistence tests. Those tests need not simulate an audited application workflow merely to create their fixtures. Avoid duplicating every test at both raw and audited layers: test pure domain behavior where appropriate and transaction/audit guarantees at the public orchestration boundary.

### Scenarios are application consumers

`Oli.Scenarios` is usable independently and through the Playwright setup controller. Relevant code includes `lib/oli/scenarios.ex`, `lib/oli/scenarios/engine.ex`, `lib/oli/scenarios/runtime_opts.ex`, and `lib/oli_web/controllers/playwright_scenario_controller.ex`. It must use the audited entry points for in-scope operations rather than becoming a global bypass for raw mutations.

Actor attribution follows the represented action, not the fact that a scenario runner executes it:

| Scenario action | Intended audit actor |
| --- | --- |
| Bootstrap an author, instructor, and student | Explicit technical/system actor, e.g. `Setup PW`; created accounts are subjects |
| Create and publish a project as its author | That author |
| Create a section and invite/enroll a student as instructor | That instructor |
| Student answers activities | Routine learning; no new administrative event required |

This is desired behavior, not a claim that current directives already resolve every actor correctly. Define explicit actor selection, bootstrap handling, and job propagation. Do not silently choose the first existing author as the actor or grant extra permissions just to make setup pass. Keep system identity distinguishable from human identity and source metadata.

Use the real domain operations/directives according to `.agents/skills/build_scenario/SKILL.md`; extend scenario capabilities only where needed. Remove existing manual captures when the coordinator takes ownership, including section-creation paths. Setup can legitimately create audit rows, so assertions should scope to the tested actor/entity/operation or use a baseline after setup instead of assuming the entire log starts empty.

## Proposed PR sequence and early review gates

The owner selected **seven implementation PRs**, with **four coverage PRs as the target**. Do not subdivide coverage prospectively based on estimates or internal work areas. Only if execution demonstrates that a PR is too large will the owner and engineer consider splitting it.

| PR | Deliverable | Dependency and review gate |
| --- | --- | --- |
| 1 | Full event catalog, schema/validation and factory inserts; partition infrastructure; existing central-history migration and safe same-deployment retirement/rollback | Prove representability, honest historical conversion and safe recovery |
| 2 | Boundary + CI + one real action pilot | Prove static protection and action/audit transaction behavior before replication |
| 3 | Identity and platform administration | Accounts/auth/access, organizations/integrations, AI services, API/MCP credentials and flags; migrate supported callers |
| 4 | Authoring | Projects/publishing/collaborators, configuration, destructive actions, imports and repairs; prove async behavior inside actual work |
| 5 | Delivery and configuration | Assessment settings and settings_changes conversion/retirement, exceptions, sections/products/blueprints, DOT, remixes/updates and scheduling |
| 6 | Learner administration and operations | Enrollment, moderation, grades/progress, payments/certificates, ClickHouse administrative outcomes and remaining preferences |
| 7 | Audit Log UI/search | Complete readable/searchable history after coverage; preserve basic reader compatibility from PR-01 |
| Final integration | Combined current-revision QA and release readiness on MER-6066, then master merge queue | All seven implementation PRs integrated; not an additional implementation child |

There is no separate ClickHouse pilot PR. Assessment history stays with assessment-setting mutations in PR-05, rather than expanding PR-01 or becoming an extra PR. The first two PRs provide early feedback on contracts and enforcement; use internal review checkpoints without turning every domain block into another PR.

### Sizing expectations for the harness

Preserve the four coverage groups. Record entry-point fan-out, transaction/bulk/async complexity, test adaptation and risks to guide execution and review, not to increase the planned PR count. The groups may be medium/large and need not have identical sizes. Keep per-domain tasks and tests within each group. If actual execution makes a PR unreviewable, show the concrete scope/diff and agree on a split then.

Every PR still needs explicit actions, exclusions, dependencies, data impacts, validation and completion gates. Account for every Jira family and existing event, with no residual unowned contexts. Field ownership and shared-context coordination are more important than enforcing equal action counts.

### Harness artifacts and Jira subtasks

Use this document with the ticket as input to `harness-analyze`, producing `prd.md` and canonical `requirements.yml`; review those before `harness-architect` produces `fdd.md`, then use `harness-plan` for `plan.md`. Keep artifacts under `docs/exec-plans/current/features/audit-log-expansion/` and follow installed skills and `harness.yml`. The general workflow and Mermaid are documented in `docs/README.md`; issue tracking is defined in `docs/ISSUE_TRACKING.md`.

At the end of initial planning, prepare one proposed Jira subtask per planned implementation PR, rather than one vague subtask per broad phase. This is the chosen organization for MER-6066; team policy permits optional subtasks and does not universally require that mapping. For this plan, seven implementation phases map to seven draft subtasks; internal work areas do not create extra subtasks. Reconsider a coverage split only on execution evidence and owner agreement.

Each subtask draft should contain its parent `MER-6066`, project/type, summary, concrete scope, exclusions, dependencies, linked requirements, relative size/risks, tests, and intended integration destination. Review the PR split first, then obtain explicit approval of the concrete Jira drafts before creating them. Read back real created keys and update traceability; never invent keys or assume a harness command creates issues automatically. Subsequent branch/worktree operations also follow the personal confirmation workflow.

## Execution constraints

- Reuse implementation branch `MER-6066-audit-log-expansion`, integration branch `story/MER-6066-audit-log-expansion`, and the existing MER-6066 worktree. Both branches were prepared from `237980b77c`. Do not recreate, rename, reset, or switch them as a side effect of planning.
- Implementation PRs target `story/MER-6066-audit-log-expansion`. New implementation branches normally start from its current tip; an explicitly arranged dependent PR may start from its prerequisite while still targeting integration.
- Follow `guides/process/development.md` and `.agents/skills/integration_branch_workflow/SKILL.md`, routed through the installed personal `integration-branches` coordinator. Implementation/sync PRs require review, passing checks, and merge commits. Verify remote protection/CI coverage before publication; branch naming alone does not prove it.
- The completed integration branch targets `master`. Final acceptance is on the current integration PR preview, with renewed QA after fixes or syncs, then the merge queue. The current plan does not request an early integration draft PR.
- Before commits, publication, PR creation, branch/worktree workflow mutations, or Jira changes, present the concrete proposed stage and obtain the required personal confirmation. Authorization to write this informal document does not authorize those actions.
- Generate new migrations with `mix ecto.gen.migration`; use explicit `up/0` and `down/0`, never manually invented timestamps. Do not rewrite old migration files to retrofit this feature.
- Do not reset or migrate the shared database during discovery. Migration/testing work must use a verified isolated database. Inspect `mix.exs`, `config/test.exs`, and environment overrides before running tests: the test alias performs database setup and can be affected by the configured database URL.
- Execute Mix commands with escalated permissions on the first attempt, as required by `AGENTS.md`. Use `run-server` on configured port 4000 when server execution is needed.
- Run appropriate tests before commits. If shared test configuration/support changes, run the full suite and preserve the repository's clean ExUnit-output requirements.

## Decisions to close in the next harness stages

These questions are explicit follow-up work, not permission to omit corresponding scope:

1. **Analysis:** enumerate concrete actions and supported channels; define meaningful changes, no-ops, bulk event cardinality, asynchronous outcomes, and minimum useful search behavior. Reconcile the catalog with every Jira criterion and existing event.
2. **Architecture:** finalize columns/JSON payloads, actor/system identity, snapshots, version-conditional validation, timestamp semantics, safe field policies, and migration provenance. Prove complex examples fit before broad implementation.
3. **Architecture and pilot:** choose a Boundary topology that actually restricts raw mutations; verify test support and compiler coverage, internal composition, direct-write escape paths, and transaction ownership. Confirm the ticket's decoupling interpretation in review.
4. **Architecture and operations:** justify partition interval using explicit evidence; define partition provisioning, indexes/identity, production cutover, mixed-version deployment behavior, historical validation, and rollback without silent data loss.
5. **Assessment design:** settle safe legacy conversion, source-ID mapping, ordering/grouping limitations, external-consumer checks where applicable, and retirement/rollback of `settings_changes`.
6. **Scenario design:** define technical bootstrap actors and explicit human actor selection without weakening authorization; identify directives needing changes.
7. **Planning:** size the inventory, finalize similarly reviewable PRs and dependencies, specify per-PR tests and final QA, and prepare the concrete subtask drafts for approval.

No application implementation, database migration, harness-generated formal artifact, Jira subtask, commit, or PR is created by this document.
