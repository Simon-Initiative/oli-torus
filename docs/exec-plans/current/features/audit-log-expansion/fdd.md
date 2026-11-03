# Audit Log Expansion - Functional Design Document

## 1. Executive Summary

Implement domain-owned audited coordinators backed by a typed event catalog and PostgreSQL time-partitioned event storage. Reuse Oban for asynchronous execution and central events for durable outcome history; do not introduce a generic operation registry. Keep mutation code separate from event construction. Extend the existing administrator Audit Log, consolidate assessment history, and preserve the original 16 event meanings.

This is the proposed technical design for review, based on MER-6066, the owner-approved PRD scope, and repository revision `237980b77c`. No dependency installation, compilation experiment, benchmark, database migration, or implementation is claimed by this document. `verified_fdd` means a criterion has a design and verification route; it does not mean the owner approved this FDD or the feature was implemented.

Selected directions:

- Use a common event envelope plus explicit per-event contracts; store typed changes and minimal immutable identities instead of arbitrary struct dumps.
- Use six-month UTC partitions, retaining the logical `audit_log_events` name and legacy event IDs. Provision future partitions; do not enable retention deletion.
- Use a controlled maintenance cutover as the initial deployment design. Rehearsal determines whether its duration is acceptable; an online-copy design is a separate decision if it is not.
- Retain the read/mutation/coordinator responsibilities, with a proposed namespace refinement: place raw mutations under `Accounts.Audited.Mutations` so the `Accounts.Audited` boundary can keep them private. Section 4 explains why the sibling names originally discussed are insufficient by themselves.
- Use Oban for job state and retries, with immutable central events for initiation and confirmed outcomes. The owner approved removing the proposed operation table from the base design; any additional coordination storage needs a concrete uncovered case. An initiation event is never inferred to be success.
- Preserve unknown historical values and redact secrets. Central history replaces `settings_changes`; no permanent double-write remains.

## 2. Requirements & Assumptions

`docs/exec-plans/current/features/audit-log-expansion/requirements.yml` is canonical for 40 requirements and 105 criteria. All action families share the envelope, secrecy, authorization, transaction, and channel rules. Section 13 maps every criterion to this design and its verification.

The owner confirmed search by actor/entity, action, period, and project/section; existing administrator-only access; exclusion of no-op saves and canceled edits; durable asynchronous failure outcomes; and no new failed-login category. Ordinary learning and automatic scoring remain excluded. Administrative intervention in learner records remains included.

Assumptions and limits:

- The same completed integration reaches `master` before normal release. This does not imply simultaneous deployment of every node or eliminate migration ordering.
- Account creation/recovery may involve a newly established principal or a trusted system identity. An arbitrary supplied actor is never authorization.
- Existing domain authorization, editing locks, publication versioning, and learner-state rules remain authoritative.
- PostgreSQL 18 is used by the checked-in development and build-service images. Verify actual target deployments before migration; do not infer their versions from local configuration.
- Workload size, production privileges, permitted maintenance duration, and external SQL consumers have not been measured/confirmed. Section 16 makes their release gates explicit.
- Architecture changes below are proposals, not permission to create branches, publish PRs, mutate Jira, or execute migrations.

## 3. Repository Context Summary

### 3.1 Existing assets to reuse

- `lib/oli/auditing.ex`: capture, listing, lookup, browsing, and association loading. `lib/oli/auditing/log_event.ex` has the existing enum and display helpers.
- `lib/oli_web/live/admin/audit_log_live.ex` and `lib/oli_web/live/admin/audit_log/table_model.ex`: the existing paged administrator surface. Its route in `lib/oli_web/router.ex` uses `:require_authenticated_system_admin`.
- `lib/oli/delivery/section_creation_auditor.ex` and `test/oli/delivery/section_creation_test.exs`: configurable internal sink and audit-failure rollback testing. Sink selection is application configuration, not caller input.
- `lib/oli/accounts.ex`: simple raw deletes and an already-transactional `admin_update_author/3` with row locking and role snapshots. Move the latter's audit responsibility rather than wrapping it and duplicating events.
- `lib/oli/delivery/settings/assessment_settings.ex`: an existing Multi for single-setting changes, including auto-submit maintenance and a cache update. Bulk apply in `lib/oli_web/live/sections/assessment_settings/settings_table.ex` performs several direct updates and separate history insertion.
- `lib/oli/delivery/settings/student_exceptions.ex`: shared exception operations, with create/update/delete and bulk deletion; updates can also maintain auto-submit jobs. This is an application boundary to migrate, not just a UI handler.
- Oban 2.17.12 and Ecto SQL 3.13.2 are locked dependencies. `config/config.exs` and `config/runtime.exs` both define Oban plugins/queues; additions must not disappear under the runtime override.

### 3.2 Concrete failure and migration pressure

The current central schema has no event-specific contract for `details`, no working system-actor admission, and live joins for identity search. Generic resource mapping can put a non-resource-table ID into `resource_id`. Those mappings must be corrected deliberately.

`lib/oli/publishing.ex`, Google Doc imports, attempt deletion, and flags/rollouts have different transaction and error-handling patterns. Existing coverage cannot be preserved merely by retaining enum values.

`lib/oli/clickhouse/admin_operations.ex` captures initiation, then uses `Task.start/1` and PubSub/telemetry for completion. Replace the durability gap, preserving existing progress messages as presentation. `lib/oli/authoring/project_repair/repair.ex` can return `{:ok, %RepairResult{status: :failed | :partial}}`; tuple success alone is not an audit success classifier.

Authentication has both `log_in_*` and `create_session` paths in `lib/oli_web/user_auth.ex` and `lib/oli_web/author_auth.ex`. Author login may also link accounts; user login may persist preferences. Session establishment and those mutations require distinct semantic events without duplicate login captures.

`Oli.Scenarios.RuntimeOpts` currently chooses the first existing author/institution when options are absent. That convenience is not a safe basis for historical attribution. The technical bootstrap actor and represented human actor must be explicit.

Boundary is not installed. A text waypoint search finds `OliWeb` references in 35 files under `lib/oli`; this is a migration warning, not an exact compiler dependency inventory. The pilot must classify existing dependency debt without weakening protected mutation boundaries.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

| Component | Responsibility and public boundary |
| --- | --- |
| Existing domain context, e.g. `Oli.Accounts` | Queries and existing not-yet-migrated operations during development; remove unaudited public shortcuts for every migrated operation |
| `Oli.Accounts.Audited` and domain equivalents | Public application commands and composable Multi builders; authorization orchestration, persisted before-state, mutations, event proposals, and transaction ownership |
| `Oli.Accounts.Audited.Mutations` | Internal domain writes; no audit insert or event construction; preserve domain validation and locking behavior |
| `Oli.Auditing.Context` | Trusted actor, source, operation identity, and correlation value object; no process dictionary or user-supplied actor override |
| `Oli.Auditing.EventCatalog` and family builders | Enumerated event contracts, safe-field projection, identity normalization, change semantics, and validation |
| `Oli.Auditing` | Validated append/browse/lookup API; does not know how to delete a user, publish a project, or change a grade |
| Domain Oban workers | Execute durable administrative work through its audited application boundary; preserve initiator and stable step identity |
| `Oli.Auditing.Partitions` and maintenance worker | Provision/check partitions with bounded DDL, report readiness, and expose an operator command |

Proposed module names are new unless identified as existing. Avoid a generic callback framework that owns all business behavior: each domain still builds the actual Multi and event payload.

#### Boundary topology and the namespace refinement

Boundary exports modules, automatically exposes a boundary root, and permits a parent to use direct child exports. It does not make sibling `Accounts.Mutations` private merely because `Accounts.Audited` exists. [Boundary documentation](https://boundary.hexdocs.pm/Boundary.html)

Select a small boundary around each audited facade and its internal implementation. `Accounts.Audited.Mutations` is an ordinary unexported module inside the `Accounts.Audited` boundary, not a separate boundary root. Keep `Accounts` outside that boundary. This changes the illustrative mutation namespace, not the three responsibilities or ticket's decoupling requirement.

Pilot configuration narrowed by the owner on 2026-11-03 to protect audited account internals only, without policing existing context relationships:

```elixir
defmodule Oli do
  use Boundary, deps: [Oli.Accounts.Audited], check: [in: false]
end

defmodule OliWeb do
  use Boundary, deps: [Oli.Accounts.Audited], check: [in: false]
end

defmodule Oli.Accounts.Audited do
  use Boundary, top_level?: true, exports: []
end

# Ordinary private module inside the audited boundary, not a boundary root.
defmodule Oli.Accounts.Audited.Mutations do
  # Domain writes only.
end
```

Legacy boundaries permit incoming calls but retain outgoing checks. The audited boundary is independent, has both checks enabled, and exports only its root. Therefore the legacy incoming compatibility setting cannot expose private audited modules. Classify Mix tasks and standalone namespaces with the same compatibility settings, preserving compiled test-support checks. Do not disable outgoing checks on callers or incoming checks on audited boundaries. No legacy `dirty_xrefs` list or cross-context refactoring is required for this pilot. See the PR-02 detailed design and execution record for compiler proof and coverage limits.

Compile a controlled forbidden-call fixture from the read context, a LiveView/controller boundary, and a Scenario caller; verify that allowed facade calls succeed. Enable the Boundary compiler ahead of the existing compiler list and use forced compilation with warnings as errors in CI. Establish behavior in both relevant dev/test builds without running a database reset. [Boundary compiler documentation](https://boundary.hexdocs.pm/Mix.Tasks.Compile.Boundary.html)

Only trusted internals of an audited boundary can call its raw mutations. Boundary cannot prove event correctness or detect every dynamic call/direct SQL write. The pilot must document those limits and reject the design if ordinary static consumers can bypass it. Keeping exact sibling names would require additional boundary extraction and dependency changes; prefer the smaller private namespace unless review requires otherwise.

### 4.2 State & Data Flow

```mermaid
sequenceDiagram
    participant Entry as UI / API / MCP / Scenario
    participant App as Domain.Audited
    participant DB as PostgreSQL
    participant Raw as Audited.Mutations
    participant Audit as Oli.Auditing
    Entry->>App: command(trusted context, target, input)
    App->>DB: begin; authorize and lock state; check replay where applicable
    App->>Raw: domain mutation
    Raw->>DB: write domain state
    Raw-->>App: persisted result
    App->>Audit: validated event proposals from before/after
    Audit->>DB: append events
    alt any required step fails
        App->>DB: rollback
        App-->>Entry: error
    else all required steps succeed
        App->>DB: commit
        App-->>Entry: domain result
        App->>Entry: publish/invalidate after commit as applicable
    end
```

A command has one operation ID. Local successful commands emit one event per affected semantic entity with all relevant changed fields in that event. A bulk command emits one such event per changed target, sharing its operation ID. It does not emit an additional indistinguishable parent success event. Lifecycle operations may have initiation and terminal events, with explicit outcomes and different event keys.

For nested domain work, compose Multi builders under one transaction and context. Each child owns its distinct semantic events; the parent must not recapture them. Namespace Multi step names and event keys. An unrelated internal SQL write, derived cache record, or revision bookkeeping row is not automatically a separate event.

### 4.3 Lifecycle & Ownership

- The authenticated adapter constructs actor/source context; the domain coordinator reloads/authorizes the target. Source is a fixed code value, not a client assertion.
- Operation IDs are allocated once per logical command and retained through retries. UI forms/live state retain them until completion; API/MCP retries reuse their documented authenticated request identity where supported; jobs persist the ID. Bind reuse to actor, command, and target, rejecting mismatches. Different commands receive new IDs.
- Correlation IDs alone do not enforce idempotency. Each retryable command defines its serialization, completion evidence, and safe replay response using domain state and retained central events where sufficient. There is no universal stored-response replay API; credential creation cannot replay the original secret from audit storage.
- Raw mutations return domain values/errors. Builders return validated event proposals. Only the transaction owner commits and executes post-commit effects.
- Events are append-only application evidence. Oban owns job execution state; historical outcomes survive job pruning in the central log. Outcome corrections append evidence instead of rewriting earlier events.
- Schema/event registry changes belong to the audited domain owner and central auditing contract tests. Unknown event names and unsafe fields are rejected.

### 4.4 Alternatives Considered

| Alternative | Decision |
| --- | --- |
| Add audit inserts inside existing mutation functions | Reject: conflicts with the agreed decoupling and makes semantic composition harder |
| Add independent audit code to each handler | Reject: duplicates orchestration across UI/API/MCP/jobs and leaves alternate callers exposed |
| Separate sibling mutation boundary with the originally illustrated names | Possible with more dependency restructuring; prefer internal mutations under the facade boundary for the pilot |
| Carbonite/row triggers for all auditable tables | Not selected: the required unit is a semantic administrative action, with explicit actors and async outcomes; no claim about unmeasured trigger overhead |
| Only transient tasks/PubSub or Oban state for lifecycle evidence | Insufficient: outcome history must survive process loss and job pruning; reuse Oban for delivery and central events for evidence |
| Generic `audit_operations` table for every command | Removed after owner review: synchronous commands use mutation + audit transactions; asynchronous work starts with Oban + central events. Reconsider narrowly scoped coordination storage only for a demonstrated gap, first checking existing domain records |
| Monthly versus annual partitions | Monthly adds maintenance objects without measured need; annual reduces objects but gives coarser future retention. Start with six months |
| Online dual-writing migration | Defer: significantly more coordination and divergence risk. Use a rehearsed maintenance cutover unless measured size/window makes it unsuitable |

## 5. Interfaces

### 5.1 Application-facing contracts

Illustrative signatures; implementation must preserve each caller's domain result/error semantics through explicit adapters:

```elixir
Context.for_actor(actor, source: :ui, operation_id: uuid)
Context.for_system(:playwright_setup, source: :scenario, operation_id: uuid)

Accounts.Audited.delete_user(context, user_id)
# => {:ok, deleted_user} | {:error, domain_or_audit_error}

Accounts.Audited.delete_user_multi(multi, step_prefix, context, user_id)
# => Ecto.Multi; composed by another coordinator without committing independently

Auditing.EventCatalog.build(event_type, context, target, before, after, safe_metadata)
# => {:ok, event_proposal} | {:error, changeset}

Auditing.append(multi, step_name, proposal_fun)
Auditing.browse_events(paging, sorting, browse_options)
Auditing.get_event!(id, inserted_at)            # efficient exact partition lookup

# A domain-specific async coordinator owns the Multi containing both
# the initiated event and Oban job insertion; it returns safe correlation/job refs.
# No generic Operations.enqueue or persistent operation-row API is introduced.
Auditing.Partitions.ensure_through(utc_date)
# => {:ok, partition_report} | {:error, operational_error}
```

`Context` contains actor kind/stable ID/safe snapshot, source, operation ID, and optional parent operation ID. The internal system constructor accepts a fixed catalog of system identities, not arbitrary request strings. Initial identities cover Playwright bootstrap, authenticated-provider account provisioning, and scheduled administrative maintenance/update work. A not-yet-created account is the subject of provisioning; do not invent an existing human actor. Where verified self-registration establishes the principal within the transaction, the domain contract can attribute that verified account explicitly. Do not export a caller-controlled `skip_audit`, sink override, or legacy-version option.

Mutation failures preserve domain changesets where callers expect them. Audit failures expose a stable error code and correlation ID; avoid inspecting changesets containing sensitive input. Do not change callers to treat every `{:ok, result}` as business success: repair and other result structs have explicit status semantics.

Retain `capture/4`/`capture!/4` only as a narrow existing-event adapter while producers move. The storage PR adapts necessary existing callers to provide correct target/source information; the adapter emits version 2, not new legacy rows. It cannot invent deleted identities or secretly start a transaction after the domain change committed. Later coverage PRs relocate such producers to the shared transaction. Final acceptance requires that remaining adapter callers satisfy the same guarantees.

### 5.2 Initial event catalog and domain waypoints

The following contracts are the initial implementation vocabulary. A comma-separated list enumerates event names; names ending in “changed” group related safe field diffs, not arbitrary payloads. Existing event names remain stable. Lifecycle events use `outcome` to distinguish stages. Builders must enumerate the actual supported setting keys from domain changesets and reviewed configuration inputs, with tests catching newly accepted persisted settings that lack audit treatment.

| Family / event names | Required subject, scope, and pertinent payload | Current implementation waypoints |
| --- | --- | --- |
| `user_logged_in`, `author_logged_in`, `user_logged_out`, `author_logged_out`, `session_revoked` | Account subject; authentication method for login; safe opaque session reference/count for revocation; actor separate for administrative revocation; no raw session identifier/token | `lib/oli_web/user_auth.ex`, `lib/oli_web/author_auth.ex`, session/LTI/OAuth controllers, `lib/oli/accounts.ex` |
| `account_created`, `account_updated`, `account_locked`, `account_unlocked`, `account_linked`, `account_permissions_changed`, `account_creation_rights_changed`, `account_recovery_requested`, `account_credential_recovered`; existing `user_deleted`, `author_deleted`, `author_role_changed`, `account_internal_flag_changed` | Typed user/author entity; affected person; safe profile/access/link state; related account for linking; recovery lifecycle without credentials | `lib/oli/accounts.ex`, account detail LiveViews and collaborator/session flows |
| `project_created`, `project_duplicated`, `project_imported`, `project_deleted`, `project_ownership_changed`, `project_collaborator_changed`; existing `project_published` | Project; source project/archive reference when applicable; publication ID/version; affected owner/collaborator and relationship change | `lib/oli/authoring/course.ex`, `lib/oli/authoring/collaborators.ex`, `lib/oli/publishing.ex` |
| `assessment_settings_changed`, `assessment_settings_reset`; legacy-only `assessment_setting_changed` | Section + assessment resource; per-setting override/effective-value changes; password changed marker only; legacy source key/string values | `lib/oli/delivery/settings/assessment_settings.ex`, `lib/oli_web/live/sections/assessment_settings/settings_table.ex` |
| `student_exception_created`, `student_exception_updated`, `student_exception_deleted` | Section + assessment + affected student; exception ID when present, otherwise stable composite identity; override before/after. MER-6066's "exception/exemption" names one concept: Torus has no separate exemption feature (owner decision 2026-10-30) | `lib/oli/delivery/settings/student_exceptions.ex`, student exception LiveViews |
| `dot_settings_changed`, `activation_settings_changed`, `instructor_ai_recommendation_changed` | Project/section/content target; configured activation conditions, safe prompt/recommendation configuration and identity; no learner chat dump | `lib/oli/experiments.ex`, `lib/oli_web/controllers/api/trigger_point_controller.ex`, AI assistant/configuration flows |
| `section_remix_saved` | One event per affected curriculum entry; section, resource, source publication, previous/resulting parent, order, and visibility; shared save operation | `lib/oli/delivery/remix.ex`, `lib/oli_web/live/delivery/remix_section.ex` |
| `authoring_content_removed`, `authoring_content_replaced`, `bank_question_deleted`, `media_deleted`; existing `google_doc_imported` | Project/content identity, resource/revision references, relevant source/replacement relationship; no unbounded full document dump | `lib/oli/authoring/editing/`, `lib/oli/authoring/project_repair/repair.ex`, `lib/oli/google_docs/import.ex`, resource/media APIs |
| `discussion_post_deleted`, `discussion_thread_deleted`, `discussion_moderated` | Post/thread, author as affected person when applicable, section/resource, moderation state; actor distinguishes self/admin deletion | `lib/oli/resources/collaboration.ex`, discussion API/LiveViews |
| Existing `resource_attempt_deleted`; `learner_attempt_reset`, `learner_progress_restored`, `manual_grade_changed`, `learner_regraded` | Affected learner, section/resource/attempt, pertinent score/progress state and intervention reason/reference where supported | `lib/oli/delivery/attempts/core.ex`, progress/manual-grading/restore LiveViews |
| `project_settings_changed` | Project; safe diffs for visibility, duplication permissions, learning model, experiments/alternatives, activities/tools, surveys, and remaining persisted project settings | `lib/oli/authoring/course.ex`, course-author workspace configuration |
| `authoring_settings_changed`, `learning_objectives_changed`, `curriculum_changed` | Project plus assessment/bank/objective/curriculum target; configuration or relationship diff | `lib/oli/authoring/`, `lib/oli/resources/`, authoring APIs |
| Existing `section_created`; `section_deleted`, `section_archived`, `section_settings_changed`, `product_created`, `product_deleted`, `product_archived`, `product_settings_changed`, `blueprint_created`, `blueprint_deleted`, `blueprint_archived`, `blueprint_settings_changed` | Typed entity; section/project scope as applicable; schedule/access/registration/delivery/survey fields or lifecycle identity | `lib/oli/delivery.ex`, `lib/oli/delivery/sections.ex`, blueprint/product application paths |
| `invitation_created`, `invitation_accepted`, `enrollment_changed`, `instructor_access_changed` | Affected person/invitation and section/project; previous/resulting role/status; no invitation secret | Account invitation flows and delivery enrollment/access functions |
| `publication_applied`, `publication_update_policy_changed` | Section + source project; old/new publication or auto-update policy | `lib/oli/publishing.ex`, `lib/oli/delivery/updates/worker.ex` |
| `gating_changed`, `prerequisite_changed`, `curriculum_schedule_changed` | Section + resource/condition; prior/resulting condition/schedule; batch operation where applicable | `lib/oli/delivery/gating.ex`, gating/scheduling LiveViews/APIs |
| `discussion_settings_changed`, `notes_settings_changed`, `student_support_settings_changed` | Configuration owner and section/project/resource scope; safe setting diffs | Collaboration configuration and section-settings paths |
| `payment_settings_changed`, `pricing_changed`, `discount_changed`, `payment_code_administered`, `entitlement_changed` | Product/section/institution and beneficiary as applicable; amounts/currency, discount, lifecycle, or entitlement state; no redeemable secret/payment instrument | `lib/oli/delivery/paywall.ex`, `lib/oli_web/live/sections/paywall_settings.ex` |
| `certificate_settings_changed`, `certificate_granted`, `certificate_revoked` | Certificate/section; recipient distinct from actor; safe configuration or decision | `lib/oli/delivery/certificates.ex`, `lib/oli/delivery/granted_certificates.ex`, certificate LiveViews |
| `institution_settings_changed`, `community_settings_changed`, `publisher_settings_changed`, `research_consent_settings_changed` | Typed organization/consent configuration and relevant scope; safe relationship/configuration diffs | `lib/oli/institutions.ex`, groups/community and research-consent configuration |
| `lms_settings_changed`, `sso_settings_changed`, `lti_settings_changed`, `external_tool_settings_changed`, `roster_settings_changed`, `grade_passback_settings_changed` | Registration/deployment/tool or organization/section identity; safe configuration, never signing material or launch payload | Institution, registration, external-tool, LTI and roster configuration paths |
| `ai_service_settings_changed`, `credential_lifecycle_changed` | Service/model or typed API/MCP credential identity; owner/author/project scope; lifecycle enum `created/rotated/enabled/disabled/revoked`; no credential value | GenAI configuration, `lib/oli/mcp/auth.ex`, MCP-token administration |
| Existing `feature_flag_enabled`, `feature_flag_disabled`, `feature_flag_removed`, `feature_rollout_stage_changed`, `feature_rollout_stage_deleted`, `feature_rollout_exemption_upserted`, `feature_rollout_exemption_deleted` | Feature/control identity, typed scope, previous/resulting enabled state/stage/exemption | `lib/oli/scoped_feature_flags.ex`, `lib/oli/scoped_feature_flags/rollouts.ex` |
| `administrative_operation`; existing `clickhouse_admin_operation_initiated` plus `clickhouse_admin_operation_outcome` | Operation/entity scope; kind, outcome, safe result summary and related entity refs; initiated never implies succeeded | Admin import/repair/delete/restore flows, `lib/oli/clickhouse/admin_operations.ex` |
| `preferences_changed` | User/author subject, safe persisted preference diffs; no transient browser-only state | Account preference and consent persistence paths |

A name is admitted only for an existing supported action. Detailed design must split ambiguous operations discovered during waypointing rather than use a catch-all event with unrestricted data. The catalog provides contracts for all requested families; the plan still needs the exhaustive caller/function inventory and per-action sizing. Routine derived-state maintenance, export cache URLs, learning writes, and configuration reads are not included solely because a generic function can update them.

### 5.3 Browse contract

Extend `BrowseOptions` with validated `date_from`, exclusive `date_to`, `project_id`, `section_id`, actor kind, event type, and text. Validate integer IDs and finite enum values without creating atoms from request input. Use UTC internally and convert displayed/local date bounds consistently.

Search fixed identity text: actor/subject IDs and labels, entity type/ID/title/slug, and safe scope labels. Generate a `simple` full-text vector from that text; use bound parameters and validated lexical prefix terms to retain existing prefix-search behavior. Do not search arbitrary JSON values. Use exact ID predicates alongside text where appropriate. A stored-vector GIN index supports this query shape. [PostgreSQL text-search indexes](https://www.postgresql.org/docs/18/textsearch-tables.html)

Preserve current pagination/sort controls initially; always add `(inserted_at, id)` or equivalent stable tie-breakers. Return page rows separately from total counts so an empty page can still show the correct total. Clamp page sizes to 100. Fetch only page-row display data and details on demand; never load all matching JSON payloads to paginate in Elixir.

## 6. Data Model & Storage

### 6.1 Central event table

Retain logical table `audit_log_events`, backed by a new partitioned parent. Proposed physical fields:

| Field | PostgreSQL type / rule | Meaning |
| --- | --- | --- |
| `id` | bigint, generated from one sequence | Every row, including migrated central and settings-history rows, receives a new ID from the sequence; original IDs are kept only as `legacy_id` provenance |
| `inserted_at` | timestamp(6), UTC, non-null | Record time and partition key; original time for migrated history |
| `occurred_at` | timestamp(6), UTC; required for v2 | Business occurrence time; usually equal to record time, distinct for recovered external outcomes |
| `schema_version` | smallint, non-null, allowed 1 or 2 | Historical format versus new contract; default new writes to 2 |
| `event_type` | text, non-null | Enumerated catalog name; preserve original names |
| `outcome` | text; v2 enum | `succeeded`, `initiated`, `failed`, `canceled`, `partial`, `unknown`; v1 may be unknown/null |
| `user_id`, `author_id` | bigint, nullable | Acting account IDs, retaining existing meaning |
| `actor_type`, `actor_key` | text | v2 type `user/author/system`; system key from fixed catalog; `unknown` allowed only for v1 |
| `actor_snapshot` | jsonb | Minimal event-time name/email or system label and stable identity |
| `entity_type`, `entity_id` | text | Explicit primary subject, supporting numeric IDs, UUIDs, stable config keys, and documented composite refs |
| `entity_snapshot` | jsonb | Safe event-time title/name/slug or identity label |
| `affected_user_id`, `affected_author_id` | bigint, nullable | Person affected by the action, separate from actor |
| `project_id`, `section_id`, `resource_id`, `institution_id` | bigint, nullable | Common indexed scope dimensions; resource_id is only a real resource ID |
| `refs` | jsonb array, default empty | Other typed references with a `role` (scope, source, previous, resulting, linked, provider) and minimal snapshot labels; known project/section/resource/institution IDs always use their columns |
| `changes` | jsonb object, default empty | Typed per-field change records described below |
| `details` | jsonb object, default empty | Allowlisted event-specific metadata and sanitized legacy payload |
| `source` | text; v2 enum | `ui/api/mcp/job/scenario/system/application`; application is explicit internal provenance, not invented transport |
| `operation_id` | uuid; required for v2 | Logical command correlation |
| `event_key` | text; required for v2 | Stable server-owned semantic slot within the operation |
| `legacy_source`, `legacy_id` | text / bigint, nullable | Backfill provenance, e.g. central table or settings row |
| `search_text` | text, non-null, default empty | Safe projected identity text only |
| `search_vector` | stored generated tsvector | Derived from search_text with a fixed configuration |

Do not add foreign keys to deletable actor/entity/scope tables. A history row must survive those deletions. Actor/subject types and references are validated by the operation's builder; they are not interchangeable polymorphic integers.

Use physical primary key `(id, inserted_at)` because parent uniqueness must include the partition key. Configure both fields as Ecto primary-key fields with explicit UTC microsecond timestamps. Implement ID-only lookup as a query, not `Repo.get` on a composite-key schema. Application-owned sequence allocation keeps new IDs globally distinct; the database composite key alone does not prove global uniqueness of `id`. [PostgreSQL partition constraints](https://www.postgresql.org/docs/18/ddl-partitioning.html)

Do not add a unique index on `(operation_id, event_key, inserted_at)` (independent review, 2026-10-29): a retry gets a new `inserted_at` and uniqueness would be per partition, so it would almost never catch a duplicate. A row-level trigger keeps the table append-only (PR-01 design section 4.1). Section 7 requires serialized checks of retained evidence for commands that support replay; stable keys/timestamps alone are insufficient. Do not describe this index as a global deduplication constraint.

Initial parent indexes: `(inserted_at DESC, id DESC)`, `(event_type, inserted_at DESC, id DESC)`, `(project_id, inserted_at DESC, id DESC)`, `(section_id, inserted_at DESC, id DESC)`, actor ID/time indexes preserving existing lookups, `(operation_id, event_key)`, a partial provenance index `(legacy_source, legacy_id, inserted_at)` for imported rows, and GIN `search_vector`. Evaluate entity/affected-person indexes against measured queries rather than indexing every JSON property.

### 6.2 Change and identity contracts

For normal scalar/structured settings, represent each changed field as:

```json
{
  "time_limit": {"operation": "set", "before": 30, "after": 45},
  "max_attempts": {
    "operation": "reset",
    "before": 2,
    "after": null,
    "effective_before": 2,
    "effective_after": 5,
    "result_source": "revision_default"
  },
  "password": {"operation": "set", "redacted": true, "changed": true}
}
```

Missing property, explicit null, unchanged value, and redacted value have different meanings. Builders normalize enums/dates/decimal values consistently and preserve units/currency where pertinent. Do not stringify all new changes. Legacy setting values stay strings unless their original type is reliably established.

Creation/deletion builders use minimal before/after entity projections; deleted content is identified by resource/revision/title/type, not by copying the entire document. Relation changes include stable related IDs and previous/resulting membership, parent, order, or role. Changes to large curricula emit affected-entry events sharing an operation ID, avoiding a single unbounded array. Prompts/configuration get specific field policies and size tests; do not silently truncate required evidence. Large content replacement uses retained revision references and relevant safe change summaries.

Snapshot builders allow known identity fields only. New events preserve event-time snapshots even if the current record is later renamed. For incomplete v1 history, retain known IDs and safe original details; current joins may be displayed as explicitly current information but must not be copied into event-time snapshots. Search combines historical identity with current-identity-to-ID database subqueries where needed for existing live-name searches. Do not materialize all matching identities in Elixir or silently cap matching IDs and omit valid results.

### 6.3 Validation and database invariants

`EventCatalog` exposes a fixed registry: action name, contract family, allowed actor/entity kinds, required scopes/subject fields, allowed outcomes, safe metadata keys, change fields, and no-op policy. Family builders share envelope validation; unsupported keys/names fail validation rather than becoming an unrestricted details escape hatch.

Database checks protect the following regardless of changeset use:

- Non-null version, ID, record time, event type; version is 1 or 2.
- For v2, explicit valid actor type/source/outcome; non-empty entity identity and event key; operation ID and occurrence time present; object/array JSON shapes correct.
- For v2 human actors, exactly the corresponding user or author ID exists and no system key; for system actors, a non-empty known key and no human actor IDs.
- Version-conditional mandatory scopes/affected-person columns for event families such as student exceptions and learner interventions.
- Names/outcomes and essential envelope fields satisfy a migration-owned v2 contract. Detailed field semantics remain changeset/builder validation, with direct-insert tests for essential DB invariants.

Write conditions with explicit `IS NOT NULL` and null-safe checks; a null SQL CHECK result must not accidentally admit a required-field omission. Migration tooling inserts v1 directly under controlled code; ordinary capture/build APIs do not accept a version argument. PostgreSQL application-level roles alone are not claimed to prevent arbitrary privileged SQL from inserting a v1 row.

### 6.4 Correlation, Oban, and conditional coordination storage

Do not add `audit_operations` or a generic operation-state API. `operation_id` remains a correlation UUID on events and in safe job arguments, not a foreign key or proof that execution is deduplicated. Synchronous commands need no job or additional coordination row merely to commit a mutation and its event together. No-op commands produce no audit event and acquire no permanent operation row.

Use existing Oban jobs for asynchronous scheduling, execution state, and retries. Persist initiation and confirmed outcomes in the central log, including an allowlisted job reference where applicable, without a foreign key that would obstruct job pruning. Keep the original actor and command/target binding available after the job is gone. Central events are evidence, not a mutable replacement job queue or a store of arbitrary request/response bodies.

For commands that need replay protection, first reuse existing domain identities, constraints, locks, and retained event evidence as described in section 7.1. Oban enqueue uniqueness is not a guarantee of exactly-once execution. Do not claim generic response replay or indefinite deduplication after evidence is removed. Future event retention must account for any supported replay horizon; this feature enables no automatic event deletion.

Additional storage is conditional, not a planned default. Potential cases include a workflow spanning multiple jobs with durable aggregate progress, an uncertain external effect requiring reconciliation state, or a replay contract that must outlive available job/domain/event evidence. None has yet been shown to require a new table for MER-6066. For each candidate, document the concrete action, failure sequence, missing evidence, existing domain records considered, and smallest necessary addition before proposing schema/API changes. Asynchrony alone is not sufficient justification.

### 6.5 Partition choice and provisioning

Choose half-open UTC calendar intervals `[January 1, July 1)` and `[July 1, January 1)`. At a steady annual volume R, a half-year partition contains approximately R/2 rows versus R for an annual partition. Ten years require 20 versus 10 partitions. These are arithmetic scenarios, not measured Torus traffic. Six months offers finer future retention with modest object count; no monthly fan-out is justified yet.

Create partitions covering every source timestamp and the current interval plus four future half-years. Use no default partition initially: a missing partition fails the audited transaction and raises an operational signal instead of silently accumulating unrouted data. Monthly maintenance (owner decision) checks coverage and replenishes the horizon. Warn when less than one future interval remains; deployment readiness requires the current interval and the configured future horizon.

`Partitions.ensure_through/1` derives names/bounds from trusted UTC dates, takes a dedicated advisory lock, and performs short, idempotent DDL with lock timeout/retry. Never construct SQL identifiers from request input. Schedule the worker in both Oban configurations. Verify runtime DDL privileges; if production separates migration privileges, run the same maintenance command under the deployment/operations role on a scheduled runner instead. That privilege/scheduler choice is a release gate, not an assumption that the application can create tables.

### 6.6 Historical migration and rollback

Generate migrations normally, separating short schema changes, historical copying, validation, cutover, and retirement into explicit steps. Each migration has `up/0` and `down/0`; old migration files remain unchanged. Apply the owner-supplied [Safe Ecto Migrations guide](https://github.com/fly-apps/safe-ecto-migrations), including its [migration anatomy](https://github.com/fly-apps/safe-ecto-migrations/blob/main/Anatomy.md) and [backfilling guidance](https://github.com/fly-apps/safe-ecto-migrations/blob/main/Backfilling.md). The owner requires central table replacement and removal of its superseded source in the same implementation PR and deployment. Separate steps mean ordered execution, not separate cleanup PRs or later releases; other feature PRs still accumulate in integration before deployment.

Volume-dependent execution (owner decision, 2026-10-29): production `audit_log_events` has 6,269 rows (3.7 MB), measured by operations on 2026-10-29. The selected primary path therefore performs preparation, copy, validation, swap, and retirement as ordered steps inside one transactional migration. Any failure rolls everything back, so no copy checkpoint, advisory migration lock, or release guard is needed, and `Oli.Release.migrate/0` is unchanged. The batched procedure below, together with section 6.7's runner, release, and batching rules, is the fallback when rehearsal at production volume exceeds 60 seconds. The PR-01 detailed design (`design/pr-01-event-contracts-partitioned-storage.md`) defines both paths.

Batched (fallback) deployment procedure:

1. Preflight source row counts/date bounds, null/ambiguous legacy cases, safe-field conversion, sequence range, storage headroom, target PostgreSQL version, and privileges. Rehearse on a representative isolated copy with synthetic secrets, not printed production payloads.
2. Prepare the replacement parent, partitions, indexes, and constraints separately, under distinct physical names that do not conflict with existing tables/indexes. Creating these unused structures can precede the writer pause; it does not redirect readers or writers.
3. Enter a documented maintenance window; drain HTTP writers and administrative jobs and stop old application instances. Confirm no remaining writers before copying. Freeze the source dataset for this procedure; batching alone does not provide online catch-up or handle source changes between batches.
4. Copy central rows in bounded, independently committed batches preserving inserted_at, allocating new IDs in original ID order and recording the original ID as `legacy_id`, marking v1, sanitizing details, and populating only reliable metadata. Use keyset progress on source ID, never OFFSET pagination or a transaction spanning the entire copy. Record committed progress durably and make reruns recognize already copied rows; a failing batch cannot advance its checkpoint. Reject unhandled timestamps or ambiguous conversion rather than skipping them. Reviewable migration-local SQL/projections must not depend on future versions of application schemas or event builders. Measure and tune batch size/pacing rather than inheriting an example's constants. [Backfilling guidance](https://github.com/fly-apps/safe-ecto-migrations/blob/main/Backfilling.md)
5. Reconcile counts and deterministic projections/checksums of preserved safe fields, including intentional redactions, before taking the final exclusive lock. In a short transaction, recheck readiness, confirm the sequence is above every new and legacy ID, and atomically swap logical names while preserving grants and lookup behavior. The final lock must not cover copying, index building, or full-history validation.
6. Run readiness/smoke checks with the new application while normal traffic remains paused; record duration, locks, and tested revision. After consumer and rollback-readiness checks pass, retire the superseded source in a separate guarded step within this same deployment, then reopen traffic. Any temporarily retained original exists only for this transition; it is not a permanent unsanitized shadow or the rollback archive. If verification or retirement fails, stop/recover the deployment rather than declaring completion and opening a later cleanup PR. Removal remains conditional on safety checks, even though its delivery belongs to the same PR/deployment.

Assessment conversion later in the migration sequence uses one v1 `assessment_setting_changed` event per original row, preserving original key/time and safe string values. It does not invent a bulk grouping from equal timestamps. Set `legacy_source = settings_changes` and `legacy_id` to the original ID, while allocating a fresh central ID. Apply the same bounded-batch/checkpoint rules. Serialize the runner independently of batch transactions and use a provenance anti-join with exact original timestamp to prevent duplicate source imports; do not imply a partitioned partial unique index alone solves global provenance uniqueness.

Map `user_type=author` to author and `instructor` to user. Missing or inconsistent historical identities remain unknown. Password/secret rows retain the setting name and a redacted change marker, never either value. Already-unchanged historical rows may remain as source evidence; the new no-op rule does not justify rewriting history. Verify safe conversion before dropping old writers/storage.

Rollback must preserve v2 evidence that an old binary cannot parse. The explicit reverse procedure pauses writers, copies the complete safe event set into a nonpartitioned rollback archive with its full columns, and reconstructs the legacy-compatible table for the original event vocabulary. New event types remain in the archive rather than being mislabeled or discarded. Set restored sequences above all retained IDs, including archived-only events. Document that the old UI cannot display archived new types until roll-forward.

The assessment reverse migration reconstructs a sanitized legacy history where source mapping permits it; secret values stay absent. Full safe central evidence remains in the rollback archive even when a new structured change cannot be faithfully represented by the old strings. Rolling forward merges archived events and intervening legacy writes by preserved identity/provenance without duplication. A rollback release must retain redaction safeguards or disable the legacy unsafe settings-history write path; reverting to plaintext logging is not acceptable recovery.

This archive is rollback preservation, not a permanent second write destination. Preserve required Oban jobs, safe correlation references, and domain recovery evidence too. Drain or durably pause new administrative jobs before rollback; do not restart an older binary that cannot safely execute/reconcile accepted work under the new worker contracts. A compatible rollback release or reconciliation is required in that case, rather than deleting pending jobs. Rehearse both immediate rollback and rollback after new events, then roll-forward. If copy/archive size exceeds the accepted maintenance window, stop this deployment plan and review online migration or an explicitly staged compatible release; do not substitute an untested procedure at release time.

### 6.7 Safe migration execution rules

- **Runner serialization:** separate the migrator's coordination lock from locks on audit data. Prefer Ecto's `migration_lock: :pg_advisory_lock` for operations outside a DDL transaction, after verifying a direct/session-compatible connection and bounded retry configuration. The pinned adapter supports it; the checked-in Repo configuration does not currently select it. Do not copy `@disable_migration_lock true` without an independently verified single-runner guarantee. [Guide: migration anatomy](https://github.com/fly-apps/safe-ecto-migrations/blob/main/Anatomy.md)
- **Indexes:** ordinary index creation is appropriate on our new unused destination. If an index must be added to a populated live table, isolate its concurrent build and disable the DDL transaction while retaining runner serialization. Verify failed-build cleanup and index validity before retrying; `IF NOT EXISTS` alone does not validate an existing index. PostgreSQL does not support `CREATE INDEX CONCURRENTLY` on the partitioned parent: build leaf indexes concurrently when necessary, then attach/create the parent index with its own bounded metadata step. [Guide: indexes](https://github.com/fly-apps/safe-ecto-migrations#adding-an-index), [PostgreSQL CREATE INDEX](https://www.postgresql.org/docs/18/sql-createindex.html)
- **Constraints:** create the selected version-conditional checks immediately on the empty destination. For later checks on populated live relations, separate admission of the constraint from validation using `NOT VALID`/`VALIDATE CONSTRAINT` where supported. This does not make historically unknown fields universally non-null. [Guide: check constraints](https://github.com/fly-apps/safe-ecto-migrations#adding-a-check-constraint)
- **Timeouts:** propose a 5-second lock-acquisition timeout for short DDL/cutover steps, consistent with existing repository migrations, and separately define finite statement and transaction-duration budgets from rehearsal. `lock_timeout` limits waiting to acquire a lock; it does not limit how long an acquired lock is held. `SET LOCAL` and transaction callbacks only apply inside a transaction; nontransactional work requires scoped settings on the actual checked-out connection, restored afterward. Do not change global server defaults for this ticket. [PostgreSQL timeout semantics](https://www.postgresql.org/docs/18/runtime-config-client.html#GUC-LOCK-TIMEOUT)
- **Release integration:** `Oli.Release.migrate/0` currently runs all pending schema migrations. The implementation plan must supply an explicit phase-aware release procedure or guarded runner, including isolated-test bootstrap, so automatic startup cannot silently cross the copy/cutover gates. Keep progress metadata durable, source-specific, and secret-free. Do not introduce a second migration framework unless the existing migrator/release entry points cannot express the reviewed sequence.
- **Rehearsal:** inspect emitted migration/migrator SQL with synthetic data, observe blocking through `pg_locks`, and test interruptions after a batch commit, before/after swap, and during rollback archival. Interrupted nontransactional work must resume deterministically. Rollback copying is batched too; an explicit `down/0` is not a promise of instantaneous rollback and must not become a silent no-op that loses history.

The maintenance-window approach remains a proposal pending size/window evidence. Adopting these safety techniques does not authorize online dual-writing, additional production releases, or zero-downtime claims. A future online option would need an explicit old/new writer compatibility and catch-up design.

## 7. Consistency & Transactions

### 7.1 Local commands and replay

The outer domain coordinator creates one Multi: validate authorization, lock/read domain state, run mutation, construct and append safe events, commit. Retryable commands include their replay check before mutation. Lock target rows in stable ID order for bulk updates. Maintain existing optimistic/editing locks as well; database row locks do not replace authoring permissions or document locks.

Specify replay behavior per action rather than promising a universal persisted response. Reuse domain constraints/state where they prove completion. Where retained events provide the completion evidence, serialize attempts for the same authenticated logical command before checking those events and keep that serialization through the mutation/event commit. A transaction-scoped PostgreSQL advisory lock keyed from the operation identity is a candidate when no persistent domain row can be locked, such as after deletion; prove the protocol in the pilot before relying on it. All callers for the command must use the same protocol. A standalone check-then-insert, a correlation UUID, or Oban uniqueness is insufficient.

Under that serialization, verify actor/command/target binding and look for the same semantic event slot across retained partitions, not just the current date interval. An existing completed slot prevents rerunning the corresponding mutation; the command returns its documented safe already-applied response or domain result where still available. Do not infer completion merely from an initiation event or recreate deleted records to reconstruct an old response. Reject incompatible reuse where binding can be checked; preserve existing authorization and never return another actor's evidence. Failure rolls back domain changes and events. No-op requests have no generic replay receipt: each action must define its precondition/version behavior or identify a concrete storage gap before claiming stable no-op replay semantics.

Generate stable event keys from semantic slots, such as `account:primary:deleted`, `assessment:<resource-id>:settings`, or `remix:<entry-id>:saved`, not random values per attempt. Reuse existing completed evidence without inserting a new timestamped copy. New async phases get new times and distinct keys. Test retries across a partition boundary and concurrent attempts; the partitioned unique index does not enforce this protocol globally.

Do not let nested public coordinators allocate independent identities or publish side effects before the outer commit. Compose Multi builders with shared context. Any capture failure rolls back the owning transaction; a bare returned error tuple inside a transaction callback is insufficient unless translated to rollback.

### 7.2 Bulk settings, defaults, and learner interventions

For a synchronous bulk settings command, resolve and authorize targets, lock them, read persisted overrides/defaults, apply the currently supported per-target eligibility rules, and build events from actual results inside the same transaction. Preserve adaptive/basic and already-started-assessment restrictions. Do not use stale LiveView assessment maps as the old-state source.

Single/bulk/reset operations use the same field-policy builders. When deleting an override, record both override removal and resulting effective value/source. Secret fields compare in memory only and emit a changed marker. Skip unchanged safe fields and emit no successful settings event if the entire target is unchanged.

Keep auto-submit job maintenance in the same PostgreSQL transaction where supported by existing domain logic. Move depot/cache mutation and broadcasts after the outer commit. For workflows intentionally committing in chunks, document partial atomicity, emit committed target events per chunk, and append a confirmed partial/failure outcome as appropriate; do not present a chunked job as an all-or-nothing bulk save. Reuse existing domain progress records if multiple jobs require aggregate coordination; apply section 6.4 before proposing additional storage.

Grade and progress interventions use domain result/state semantics, preserve learner/section/attempt identity, and exclude consequent ordinary scoring/bookkeeping rows. Repairs inspect their result struct status and committed-target summaries rather than assuming `{:ok, result}` means total success.

### 7.3 Authentication

Define login evidence as server-side session issuance after successful authentication, not proof that a browser received a response. Coordinate token persistence and login event before returning the constructed session response; no audit event for an unsuccessful provider callback. Do not recapture when higher-level login calls the lower-level session helper. Correlate callback retries with the established flow identity without retaining its secret.

Author account linking and preference synchronization are separate domain changes under their audited coordinators, composed with session issuance when local atomicity permits. The transport layer owns cookies and redirects, while domain operations own database writes. A response transport failure after a committed session issuance does not retroactively mean the server did not issue that session.

Logout/revocation audit means server-side token invalidation. Persist revocation and its evidence together; clear cookies/disconnect sockets after commit. Error handling may clear a local browser cookie for safety but must not claim server-wide revocation if it failed. Use the typed non-secret token-row ID already available in `lib/oli/accounts/user_token.ex` and `lib/oli/accounts/author_token.ex`, or a separately generated audit reference, never the raw/hashed token value. Already-absent sessions are handled as no-op lifecycle results, not fabricated revocations.

### 7.4 Asynchronous and external operations

Atomically insert the initiated event and Oban job in the same Repo transaction, through the domain's audited coordinator. Existing Oban Multi insertion supports this; use the locked local dependency API in implementation. Replace fire-and-forget administrative tasks with durable jobs where a durable terminal outcome is required. Job arguments contain operation/target IDs, trusted initiator context, and safe command options; resolve service credentials at execution time. If enqueue uniqueness returns an existing job, do not emit another initiation event or bind a new actor to its old operation; verify actual insert/conflict behavior against the pinned Oban version.

Local transactional jobs update domain state, append target events, and record terminal outcome together. External ClickHouse/import/repair work first checks supported capability/idempotence, executes with a stable operation/step reference, and records confirmed outcomes. Failed retry attempts are not terminal failures until the defined retry policy is exhausted. Cancellation reports only confirmed canceled/not-started work; already committed targets remain visible.

A process crash after an external effect but before result persistence cannot be solved by PostgreSQL alone. Recovery inspects external/domain evidence or supported idempotency markers before retrying. If the outcome cannot be determined safely, append an explicit `unknown` outcome and require reconciliation instead of repeating destructive work blindly. Confirmed reconciliation appends a new outcome. No claim of universal exactly-once external execution is made, and a new table alone would not provide it.

Prove the crash boundary between committing a successful domain change/event and Oban acknowledging completion: a retried worker must recognize the committed evidence and avoid repeating the work. Retrying attempts are not definitive failure events. Final exhaustion, crashes that exhaust attempts, and supported cancellation paths need durable outcome capture/reconciliation, including cancellation outside the worker. A telemetry callback or an after-the-fact timer alone is not a durability guarantee.

Job pruning is a release gate for each migrated asynchronous flow. The checked-in configurations enable `Oban.Plugins.Pruner`; the pinned dependency defaults to a 60-second maximum age for terminal jobs. Do not assume job history is permanent or that a periodic reconciler always runs before deletion. The detailed design must establish a tested protocol that retains required job evidence until its terminal audit outcome is durable, or identify an existing durable recovery source that survives pruning. Merely increasing a fixed retention interval does not cover an unbounded outage. Do not enable the flow with an unresolved capture/pruning race; if Oban and existing records cannot meet this gate, document the concrete gap under section 6.4 before adding coordination storage.

Use Oban state and domain evidence to identify abandoned work. Reconciliation must not label a long-running live worker failed merely because a timer elapsed. PubSub remains a progress-delivery convenience; Oban supplies current execution state while retained, and central events preserve confirmed historical outcomes after reconnect and pruning.

## 8. Caching Strategy

Do not introduce a cache for audit writes or investigation results. Snapshot identity is immutable event data, not a cache of mutable accounts. Keep queries paginated and indexed.

Existing domain depot/cache invalidation must happen after commit. Where stale caches can cause incorrect behavior after a process crash, use existing durable refresh mechanisms or enqueue an idempotent invalidation in the same transaction; do not rely solely on a post-commit message for correctness. Reuse caches for current domain reads only when they do not determine authoritative before-state.

## 9. Performance & Scalability Posture

Measure event/index writes, any required replay queries/serialization, and asynchronous enqueue/reconciliation overhead; the design does not promise negligible overhead. Simple synchronous mutations have no generic operation-row insert/finalization. Batch validated event inserts within the owning transaction, avoid one association query per event, and select before-state in sets for bulk operations. Do not use unvalidated `insert_all` as a shortcut around event contracts.

Proposed review budgets, not measurements: on a fixed documented test environment, a simple local command should add no more than `max(10 ms, 20% of baseline p95)` at the same load; first-page/date-scoped searches over a one-million-event representative dataset should have p95 below 500 ms. Benchmark 100- and 1,000-target bulk operations for linear work and bounded query counts. Replace these proposed budgets with reviewer-accepted numbers before final acceptance if deployment evidence requires it; never report them as a production SLA.

Use at least several historical/current/future partition intervals and realistic identity/payload distributions. Capture write throughput, p50/p95, query plans/buffers, index/storage sizes, cross-partition searches, deep pagination, and retained-job/reconciliation backlog. Show partition pruning for bounded dates and measure all-history and replay queries explicitly. Optimize the current offset/count approach only if measured cost requires it; do not silently change UI pagination semantics during storage work.

Migration preflight records source sizes, temporary-copy/archive capacity, duration, locks, and WAL impact. Six-month selection remains contingent on that evidence. No production metrics were collected during this design.

## 10. Failure Modes & Resilience

| Failure | Required response |
| --- | --- |
| Domain validation/authorization failure | No domain change or successful event; existing caller error behavior preserved |
| Event validation/insert failure | Roll back local mutation and associated events/job enqueue; return safe failure code |
| Missing partition or DDL privilege | Fail local write safely; signal readiness/maintenance error; repair coverage before retry |
| Retry/repeated callback | Match operation binding; return existing result or continue known incomplete step; no new success copy |
| Nested legacy capture | Regression/pilot test fails expected cardinality; remove the redundant producer |
| Crash before async dispatch | Transactional Oban enqueue retains accepted work or rolls everything back |
| Job finishes/exhausts/cancels before outcome capture | Recover confirmed outcome from retained evidence; prove capture/pruning ordering and do not infer success from missing job state |
| Crash after uncertain external effect | Reconcile; show unknown/partial evidence rather than guessed success or unsafe replay |
| Actor/target deleted after the event | Use immutable IDs/snapshots; no dependency on live FK rows |
| Legacy row missing required new information | Admit v1 with explicit unknowns, never downgrade a new command |
| Unsafe legacy payload | Sanitize deterministically; preserve action/provenance and verify intentional differences |
| Cache/broadcast failure | Committed audit remains correct; use durable recovery where stale domain state matters |
| Failed migration/cutover | Keep writers paused, roll back the atomic swap or use rehearsed rollback preservation; do not resume incompatible binaries |

## 11. Observability

Use existing telemetry/AppSignal for operation duration, append failures, replay conflicts, queued-to-terminal duration, unresolved external outcomes, partition horizon/provisioning failures, and migration reconciliation summaries. Use event family/source/outcome as bounded metric dimensions, not actor names, entity IDs, or operation IDs as high-cardinality metric labels.

Safe logs may include operation ID, error category, partition interval, and worker reference. They must not contain event JSON, secret values, rejected changesets, or raw external error bodies. Translate external errors into bounded codes and safe messages before both event persistence and telemetry.

Existing feature flags and rollout controls are audited subjects. No new feature flag can disable required audit writes while allowing a protected mutation to commit.

## 12. Security & Privacy

Preserve the administrator-only route and validate authorization in the application entry point that owns each command. Actor construction uses authenticated principals or explicitly authorized internal system identities. Replay checks and job/outcome lookups must not expose another actor's result through a guessed correlation UUID.

Allowlist payload fields recursively. Keep passwords, raw/hashed tokens, credential material, invitation secrets, private keys, payment instruments, and signed authentication payloads out of events, search text, errors, and job arguments. For lifecycle records, use database credential IDs or separate opaque references, not secret-derived identifiers. Test marker secrets across every persisted/serialized sink.

Limit snapshots to relevant ID/name/email/title/slug/type fields; never copy complete account, discussion, content, or learner-attempt structs. Structured prompts/settings require explicit policies; existing revision references can preserve content identity without retaining the whole document. Do not introduce audit update/delete UI or automatic retention as part of this feature.

Historical unknowns stay distinguishable from explicit system actions. Scenarios use a controlled `playwright_setup` system identity to bootstrap accounts, then the actual author/instructor for represented actions. System identity is attribution, not a generic authorization bypass. Public tests use coordinators; only narrowly scoped internal mutation tests may call internals, with their compilation/checking limits documented.

## 13. Testing Strategy

### 13.1 Verification layers

1. Catalog tests instantiate every event contract with valid factory data and reject missing/unsafe combinations. Cover direct database constraint failures as well as changeset errors. Use representative multi-field, reset, deleted-target, system, bulk, and async payloads before broad instrumentation.
2. A real pilot command proves allowed/forbidden Boundary references, correct authorization, persisted old/new values, domain failure rollback, audit failure rollback, and exactly the intended semantic event count. Do not assert only that `capture` was called.
3. Each domain group maps all supported caller paths and existing captures to shared coordinators. Preserve functional tests, then add meaningful audit assertions at application/transport boundaries. Exercise direct writes, no-ops, concurrency, nested operations, and replay across partition boundaries. Async cases cover enqueue rollback/conflict, crash after mutation/event commit but before job acknowledgement, retry exhaustion, cancellation outside the worker, recovery outages, and pruning before/after outcome capture. Completed historical evidence remains available after the job is deleted.
4. Migration rehearsals on isolated databases cover both sources, secrets, old actor ambiguities, interval boundaries, sequences/ID lookups, duplicate backfill prevention, future-partition provisioning, batch checkpoint/restart behavior, short cutover locks, concurrent-index recovery where used, immediate rollback, post-write rollback, and roll-forward from archives.
5. UI/query tests exercise approved search dimensions, deleted identity, legacy/current labels, system actors, empty pages, sort stability, UTC/local date boundaries, access denial, and safe details. Benchmark with reproducible workloads.
6. Real Scenarios verify setup actor followed by author publishing and instructor section/invitation work. Student answers produce no added administrative event. Existing setup events are scoped out by entity/operation or a post-setup baseline, not suppressed globally.

Run focused ExUnit/LiveView/Scenario tests per PR and required broader suites before merge. Changes to shared test support/configuration require the full clean-output suite under `AGENTS.md`. Do not execute the destructive test alias until the database target is verified isolated.

### 13.2 Requirement-to-design coverage

The table below is design traceability and planned verification, not implementation proof. All criterion IDs are explicit so the nested requirements format can be checked independently of the installed flat-list validator.

| Requirement | Criteria | Design and verification route |
| --- | --- | --- |
| FR-001 | AC-001, AC-002, AC-003, AC-004 | Sections 6.1–6.3 and 7.1: envelope, subject distinction, authoritative diffs; insert and concurrent-update tests |
| FR-002 | AC-005, AC-006, AC-007 | Sections 5.2 and 6.3: complete registry and direct-insert invariants; catalog cases and plan caller inventory |
| FR-003 | AC-008, AC-009, AC-010 | Sections 4.2 and 7.1: shared transaction/no-op semantics; injected mutation/audit failures |
| FR-004 | AC-011, AC-012, AC-013, AC-014 | Sections 4.2–4.3 and 7.1–7.2: operation ownership, per-target bulk events, replay; caller/nested/retry tests |
| FR-005 | AC-015, AC-016, AC-017, AC-018 | Sections 6.4 and 7.4: durable queue/outcomes and reconciliation; crash-boundary/partial-result tests |
| FR-006 | AC-019, AC-020, AC-021 | Sections 5.2 and 7.3: shared session boundaries and explicit revocation; provider/callback failure tests |
| FR-007 | AC-022, AC-023, AC-024 | Account catalog and sections 6.2/12: creation/profile/access/link/recovery/deletion; actor/secret/history tests |
| FR-008 | AC-025, AC-026, AC-027 | Project catalog and 7.1/7.4: lifecycle/publication/relationships; source IDs, transaction and import tests |
| FR-009 | AC-028, AC-029, AC-030 | Sections 6.2 and 7.2: assessment changes/bulk/reset; eligibility/default/secret/no-op tests |
| FR-010 | AC-031, AC-032 | Exception catalog and 7.2: student subject plus scope and overrides; individual/bulk exception tests |
| FR-011 | AC-033, AC-034 | DOT/activation catalog and 6.2/12: configured conditions/prompts/recommendations; persisted-change and privacy cases |
| FR-012 | AC-035, AC-036 | Remix catalog and 4.2: per-entry committed diffs; save, cancellation, reorder/source/visibility tests |
| FR-013 | AC-037, AC-038 | Destructive-content catalog and 7.4: durable identity/revision links and repair outcomes; delete/replace/failure tests |
| FR-014 | AC-039, AC-040 | Discussion catalog and 6.2: actor versus content author; self/admin deletion and moderation tests |
| FR-015 | AC-041, AC-042 | Learner-intervention catalog and 7.2: grades/attempts/progress; partial repair and ordinary-scoring exclusions |
| FR-016 | AC-043, AC-044 | Project-settings catalog and 5.2 registry rules: field coverage including generic updates; per-setting and inventory checks |
| FR-017 | AC-045, AC-046 | Authoring-config catalog and 6.2: assessment/bank/objective/curriculum differences; relationship and settings cases |
| FR-018 | AC-047, AC-048 | Section/product/blueprint catalog: lifecycle and configuration; entity-specific actor/scope tests |
| FR-019 | AC-049, AC-050 | Access/enrollment catalog and 7.2: subject relationship transitions; invitation, roster/bulk, and secret checks |
| FR-020 | AC-051, AC-052 | Publication-application catalog and 7.4: old/new publication and policy; worker initiator tests |
| FR-021 | AC-053, AC-054 | Gating/scheduling catalog and 7.2: typed conditions and schedules; individual/bulk changed-target tests |
| FR-022 | AC-055 | Support-configuration catalog: safe scoped field diffs; configuration tests excluding routine use |
| FR-023 | AC-056, AC-057 | Paywall catalog and 12: money/code/beneficiary semantics; privacy and manual-entitlement cases |
| FR-024 | AC-058, AC-059 | Certificate catalog: configuration and administrative grant/revoke; recipient and automated-outcome distinction |
| FR-025 | AC-060, AC-061, AC-062 | Organization/integration catalog and 12: safe scope/configuration diffs; credential and transmission exclusions |
| FR-026 | AC-063, AC-064, AC-065 | AI/credential/flag catalog and 12: lifecycle controls and safe settings; existing/new coverage tests |
| FR-027 | AC-066, AC-067 | Administrative catalog and 7.4: imports/repairs/ClickHouse outcome durability; disconnect/crash/reconciliation tests |
| FR-028 | AC-068 | Preferences catalog and 7.3: persisted preferences only; settings/login-side-effect tests |
| FR-029 | AC-069, AC-070, AC-071 | Sections 3, 5.2, and 14: original 16 types preserved; producer regression and legacy-read fixtures |
| FR-030 | AC-072, AC-073, AC-074 | Sections 6.2–6.3 and 12: recursive safe fields, snapshots, redaction; sink/UI/search/exception leak tests |
| FR-031 | AC-075, AC-076, AC-077, AC-078 | Section 6.5: interval rationale, provisioning, identity and removal; isolated routing/maintenance rehearsal |
| FR-032 | AC-079, AC-080, AC-081, AC-082 | Sections 6.3/6.6/14: source reconciliation, conditional format, rollback archive; cutover/rollback/roll-forward tests |
| FR-033 | AC-083, AC-084, AC-085, AC-086 | Sections 6.6 and 7.2: per-row legacy conversion and central-only writes; dependency/secret/ID tests |
| FR-034 | AC-087, AC-088, AC-089, AC-090 | Sections 5.3 and 6.2: safe historical search/rendering and stable pages; LiveView/query/accessibility tests |
| FR-035 | AC-091, AC-092 | Sections 3.1/7/12: administrator route and domain authorization; unauthorized filter/replay/alternate-channel tests |
| FR-036 | AC-093, AC-094, AC-095 | Section 4.1: private mutation boundary and explicit debt; compiler fixtures plus bypass inventory |
| FR-037 | AC-096, AC-097, AC-098 | Sections 12 and 13.1: explicit bootstrap/human actors; real Scenario and Playwright-setup integration tests |
| FR-038 | AC-099, AC-100, AC-101 | Sections 13–14: per-PR gates and integration acceptance; reviewed coverage/size/subtask plan |
| FR-039 | AC-102, AC-103 | Sections 9–11: proposed budgets, benchmark/rehearsal records and safe diagnostics; reviewer acceptance gate |
| FR-040 | AC-104, AC-105 | Sections 2/4.2/7.2–7.3: administrative semantic boundaries; ordinary learning/no-op/cancel regression tests |

## 14. Backwards Compatibility

The first storage PR must preserve existing capture/read tests and the working Audit Log while introducing new contracts. Adapt existing event inputs explicitly; do not rely on a permanent version-1 writer. Subsequent domain PRs replace old captures and unaudited shortcuts, preserving caller behavior through narrow adapters. Comprehensive search/display comes last, basic reader compatibility does not.

Original event names remain recognized. New names require the new reader, which is why production cutover forbids incompatible mixed binaries. Schema conversion is a new migration, not an edit to historical migrations. Historical rows do not become strict new events simply because a current label could be looked up.

Assessment consolidation replaces its history writers and tests, preserving effective setting behavior. Retire old storage after conversion and consumer checks; the migration remains separately identifiable from central table repartitioning.

Review seven planned implementation PRs into `story/MER-6066-audit-log-expansion`: storage/migration, Boundary/CI with one action pilot, four coverage PRs, and UI/search. Assessment-history consolidation belongs to the delivery coverage PR; ClickHouse belongs to administrative coverage with no separate pilot PR. Internal work areas organize these larger coverage PRs without creating additional PRs/subtasks. Only actual execution demonstrating excessive size, followed by owner agreement, can trigger a coverage split. Reuse the existing worktree/implementation branch until a later approved routing action. Draft one Jira subtask per implementation PR; no branches, subtasks, commits, or publications are created in architecture work. The complete integration receives current-revision QA before the `master` merge queue and normal release.

## 15. Risks & Mitigations

| Risk | Mitigation / gate |
| --- | --- |
| Private namespace proposal differs from illustrative names | Review explicitly; prove compiled boundary behavior before broad moves; preserve responsibilities |
| Broad existing cross-layer dependencies | Inventory compiler output, classify roots, and allow only exact reviewed legacy debt; never ignore protected mutation calls |
| Removing the registry leaves assumed replay guarantees | Prove per-action domain/event serialization and retry behavior; operation IDs and Oban uniqueness are not execution guarantees |
| Oban pruning races terminal audit capture | Verify durable capture/recovery ordering before enabling each async flow; fixed retention or telemetry alone is insufficient |
| Event contracts miss a setting/channel | Full family catalog plus exhaustive action/caller inventory and registry coverage tests before each PR is closed |
| Actor bootstrap conflicts with authorization | Explicit trusted system identities and represented human actors; no arbitrary first-author fallback |
| Long bulk transactions or inconsistent before-state | Stable lock order, actual persisted diff, documented chunking only for async/partial operations |
| Unknown external outcome cannot be safely retried | Durable initiation/state, external evidence/idempotency adapters, explicit unknown and reconciliation |
| Maintenance cutover/archive exceeds window | Rehearse and measure before release; redesign migration if budget fails, never promise zero downtime |
| Old code reintroduces plaintext settings logs on rollback | Preserve redaction in rollback target or disable that legacy writer; do not restore removed secrets |
| Future partition provisioning lacks production privileges | Verify role/scheduler ownership before release; use the same provisioning API under operations privileges if needed |
| Traceability validator ignores nested ACs | Run required scripts and supplement with complete nested ID/status/reference checks; no vacuous validation claim |

## 16. Open Questions & Follow-ups

The design is concrete enough to review and plan; these are explicit gates with owners/stages, not hidden implementation omissions:

1. **Owner/architecture review:** accept the private `Audited.Mutations` namespace refinement, six-month interval, and maintenance-window cutover. These remain technical proposals, not permission to modify code. The owner has approved Oban + central events as the base for asynchronous work, without a generic operation registry, and same-PR/deployment retirement of superseded central storage after safety checks.
2. **Boundary pilot:** compile the exact topology against Torus and record allowed/forbidden examples, classification/dependency debt, and test-support limits. If the topology fails, resolve it before migrating additional contexts; do not weaken checks silently.
3. **Planning/domain owners:** complete function/caller inventory for every catalog action and supported channel, including generic updates, jobs, MCP, Scenarios, and existing captures. Determine exact PR grouping/relative sizes and dependencies; propose detailed Jira drafts only after plan review.
4. **Storage implementation/operations:** obtain target versions, source sizes, privileges, permitted maintenance window, backup/rollback capacity, and partition-maintenance ownership. Rehearse the selected migration before accepting production readiness.
5. **Performance review:** accept or revise the explicit proposed latency/query budgets using benchmark evidence. The estimates in section 9 are not test results.
6. **Assessment owner/operations:** confirm known external consumers and rollback release redaction handling before retiring `settings_changes`.
7. **Async/auth detailed design:** enumerate adapter-specific idempotency/reconciliation and session boundaries, including provider callback reuse, ClickHouse operations, import/repair partial results, and credential-replay behavior. Prove terminal capture versus Oban pruning and replay serialization without a registry. Record any concrete multi-job, external-recovery, or replay-horizon gap before proposing additional storage; no new table is currently justified. No universal external exactly-once guarantee is assumed.

## 17. References

- Product scope: [MER-6066](https://eliterate.atlassian.net/browse/MER-6066).
- Work-item source and traceability: `docs/exec-plans/current/features/audit-log-expansion/informal.md`, `docs/exec-plans/current/features/audit-log-expansion/prd.md`, `docs/exec-plans/current/features/audit-log-expansion/requirements.yml`.
- Repository contracts: `AGENTS.md`, `ARCHITECTURE.md`, `harness.yml`, `docs/STACK.md`, `docs/TOOLING.md`, `docs/TESTING.md`, `docs/PRODUCT_SENSE.md`, `docs/FRONTEND.md`, `docs/BACKEND.md`, `docs/DESIGN.md`, `docs/OPERATIONS.md`, `docs/CODEREVIEW.md`, `docs/ISSUE_TRACKING.md`.
- Domain constraints: `docs/design-docs/publication-model.md`, `docs/design-docs/locking.md`; workflow: `guides/process/development.md` and `.agents/skills/integration_branch_workflow/SKILL.md`.
- Current storage/history: `priv/repo/migrations/20250819181513_create_audit_log_events.exs`, `lib/oli/auditing.ex`, `lib/oli/auditing/log_event.ex`, `lib/oli/delivery/settings/settings_changes.ex`.
- Migration guidance supplied by the owner: [Safe Ecto Migrations](https://github.com/fly-apps/safe-ecto-migrations), [Anatomy](https://github.com/fly-apps/safe-ecto-migrations/blob/main/Anatomy.md), and [Backfilling](https://github.com/fly-apps/safe-ecto-migrations/blob/main/Backfilling.md). Apply the techniques with the repository's explicit `up/0`/`down/0` policy; sample code is not a substitute for the migration-specific safety/reversal design.
- Technical references: [Boundary module rules](https://boundary.hexdocs.pm/Boundary.html), [Boundary compiler](https://boundary.hexdocs.pm/Mix.Tasks.Compile.Boundary.html), [PostgreSQL 18 partitioning](https://www.postgresql.org/docs/18/ddl-partitioning.html), [PostgreSQL 18 text search](https://www.postgresql.org/docs/18/textsearch-tables.html). Verify compatibility with the deployment versions and pinned dependency chosen during implementation.
