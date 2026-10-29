# PR-01 Event Contracts, Partitioned Storage, and Central-History Migration - Detailed Design

Source Artifacts:
- PRD: `docs/exec-plans/current/features/audit-log-expansion/prd.md`
- FDD: `docs/exec-plans/current/features/audit-log-expansion/fdd.md`
- Plan: `docs/exec-plans/current/features/audit-log-expansion/plan.md` (Phase 1, MER-6111)
- Inventory: `docs/exec-plans/current/features/audit-log-expansion/coverage-inventory.md` (W01), `docs/exec-plans/current/features/audit-log-expansion/caller-inventory.tsv`

Status: approved by the owner on 2026-10-29 (plan Phase 1 gate: concrete schema, event contracts, and migration/retirement/rollback procedure). Code evidence refers to `ddb2d80c3e`. Nothing in this document has been implemented, executed, or measured. Owner decisions recorded so far: DB-format-only check for event names and system keys (approved); uniform ID policy with `legacy_id` provenance (approved); event descriptions in the code catalog (approved); single transactional migration as the primary path, with the batched procedure as plan B depending on production volume (approved; confirmed by production counts on 2026-10-29); monthly partition maintenance at 08:00 UTC (approved); v1 mapping rules in section 4.5 (approved).

## 1. Slice Summary

- Objective: replace the current flat `audit_log_events` table with a six-month-partitioned table that enforces a versioned event envelope, define the complete event catalog with validated contracts, convert existing central history to `schema_version = 1`, and retire the superseded table in the same PR and deployment with a history-preserving rollback.
- In scope:
  - `Oli.Auditing.Context`, `Oli.Auditing.EventCatalog`, `Oli.Auditing.Changes`, `Oli.Auditing.Snapshot`, a v2 `Oli.Auditing.LogEvent`, `Oli.Auditing.append/3`, `Oli.Auditing.Partitions`, `Oli.Auditing.PartitionMaintenanceWorker`.
  - Contracts and factory-backed insert/reject tests for every catalog event, including families whose producers arrive in PR-02..PR-06.
  - One generated migration that creates, copies, verifies, swaps, and retires in a single transaction, with explicit `up/0` and `down/0` (section 4.5). No change to `Oli.Release` and no manual deployment step. The batched procedure (section 4.7) is used only if production volume requires it.
  - A narrow `capture/4` adapter so the 16 existing event types keep their current producers and write strict v2 rows.
  - Reader compatibility: `get_event!/1`, `get_event!/2`, `browse_events/3`, `LogEvent.event_description/1`, `LogEvent.actor_name/1`, and the admin table render new and v1 rows without crashing.
  - Disposable-database rehearsal and benchmark scripts, plus an evidence report.
  - Event documentation (section 4.6): column comments, the `LogEvent` field glossary, one test-only example per event type, and the generated reference `docs/design-docs/audit-log-events.md`.
- Out of scope:
  - Moving any producer into an audited coordinator or removing manual captures (PR-02..PR-06). The existing swallowed-error behavior of feature-flag, Google Docs, and attempt-deletion producers stays as it is until their owning PR.
  - Boundary, CI compiler changes, and the user-deletion pilot (PR-02).
  - Async initiation/outcome protocol, Oban pruning gate (PR-04 first async flow).
  - `settings_changes` conversion and retirement (PR-05). PR-01 only reserves the v1-only `assessment_setting_changed` name and the `legacy_source = 'settings_changes'` provenance value.
  - New search filters, UI controls, and detailed rendering per family (PR-07). PR-01 keeps the existing page working.

## 2. Requirements Coverage

| Criterion | Coverage in this slice |
| --- | --- |
| AC-001 | v2 envelope columns and DB checks (sections 4.1, 4.2); catalog tests per event |
| AC-002 | Contracts require `affected_user_id`/`affected_author_id` separate from actor for exception, intervention, account-on-account families; DB check for exception/intervention families |
| AC-003 | `Changes` record contract (`before`/`after`, create/delete one-sided); builders take before/after from the caller, which must be persisted state (enforced per coordinator in later PRs) |
| AC-004 | `occurred_at` versus `inserted_at` contract; per-event `event_key`; concurrent-diff assertions belong to coordinator PRs, contract only here |
| AC-005 | Section 4.3 family contract table plus the code registry; the per-field key lists are produced in checkpoint A (section 5) from domain changesets; generated reference `docs/design-docs/audit-log-events.md` |
| AC-006 | `Oli.Auditing.EventExamples` provides one realistic example per catalog event, each inserted and rejected in its derived invalid variants; hand-written cases cover bulk, async, deleted-target, system-actor, affected-student |
| AC-007 | Changeset errors per contract plus raw-SQL insert rejection tests for every DB check |
| AC-069, AC-070 | Existing producers unchanged; adapter emits v2 for all 16 names; existing tests in `test/oli/auditing_test.exs`, `test/oli_web/live/admin/audit_log_live_test.exs`, `test/oli/delivery/section_creation_test.exs` retained |
| AC-071 | Historical `clickhouse_admin_operation_initiated` rows get `outcome = 'initiated'`; adapter writes `initiated` for new ones; reader labels it as initiation |
| AC-072 | Recursive denylist and per-contract allowlist; secret marker tests on details, changes, snapshots, search text, changeset errors, logs |
| AC-073 | Immutable `actor_snapshot`/`entity_snapshot` and `search_text`; no FK to deletable tables |
| AC-074 | Errors expose stable codes, not changesets; legacy sanitizer records redaction markers |
| AC-075 | Six-month versus annual benchmark and written comparison (FDD section 6.5), anchored to measured production rates |
| AC-076 | Jan 1/Jul 1 UTC boundary routing tests; composite PK; ID lookup; sequence continuity after migration |
| AC-077 | `Partitions.ensure_through/1`, monthly worker in both Oban configs, missing-partition error path, readiness report |
| AC-078 | Rehearsal detaches and drops the oldest partition on a disposable DB; no retention automation shipped |
| AC-079 | Copy assigns new IDs in original order with the original ID as `legacy_id`; preserves time, type, scope IDs, sanitized details; reconciliation of every source row |
| AC-080 | v1 rows keep unknowns as `NULL`/`unknown`; no current-record snapshots; initiation never becomes success |
| AC-081 | Public APIs never accept a version; only migrations write v1; DB checks admit v1 incompleteness |
| AC-082 | Migration, rollback (immediate and after new types), and roll-forward rehearsals; the legacy table is retired in the same migration, so in the same PR and deployment |
| AC-087 | Partial in PR-01: page renders every catalog event and v1/system rows without errors using catalog labels; full family rendering in PR-07 |
| AC-088 | Partial in PR-01: existing name/email/slug search keeps working and also matches stored `search_vector`; full search in PR-07 |
| AC-089 | Partial in PR-01: stable `(inserted_at, id)` tiebreaker; filters in PR-07 |
| AC-090 | Partial in PR-01: no secret or schema-version shown as primary content; full in PR-07 |
| AC-102 | Write and partition benchmark baseline recorded; search budgets measured again in PR-07 |
| AC-103 | Rehearsal records duration, locks, WAL, storage; safe diagnostics for append and partition failures |

FR-038 per-PR gate evidence is recorded in `docs/exec-plans/current/features/audit-log-expansion/evidence/pr-01-storage.md`.

## 3. Responsibilities & Boundaries

- `Oli.Auditing.Context` (new): value object with `actor_type`, `user_id`/`author_id` or `system_key`, `actor_snapshot`, `source`, `operation_id`, `parent_operation_id`. Built only from authenticated structs or the fixed system catalog. No process dictionary, no caller-supplied version, sink, or skip flag.
- `Oli.Auditing.EventCatalog` (new): compile-time registry of every event name and its contract (section 4.3). The single source for `LogEvent`'s `Ecto.Enum` values, families, display labels, and descriptions. Families, labels, and descriptions are code only; no database table or column stores them, and they are resolved from `event_type`.
- `Oli.Auditing.Changes` (new): validates and normalizes per-field change records, including `secret` fields that only emit `%{"operation" => "set", "redacted" => true, "changed" => true}`.
- `Oli.Auditing.Snapshot` (new): projects allowlisted identity fields (`id`, `name`, `email`, `title`, `slug`, `type`, `label`) from structs; builds `search_text`.
- `Oli.Auditing.LogEvent` (changed): v2 schema over the partitioned table; `v2_changeset/2` is the only application changeset. No `schema_version` cast.
- `Oli.Auditing` (changed): `build/2`, `append/3` for `Ecto.Multi`, `insert/1` for non-Multi writes, the legacy `capture/4` adapter, and readers. It does not know domain semantics.
- `Oli.Auditing.LegacyAdapter` (new, private to `Oli.Auditing`): maps the 16 existing `(actor, event_type, resource, details)` call shapes to v2 attributes. Removal gate: final acceptance (plan Phase 8) verifies every remaining caller satisfies coordinator guarantees.
- `Oli.Auditing.Partitions` (new): naming, bounds, `ensure_through/1`, `status/0`, `detach/1` (rehearsal and operator use only; no scheduled deletion).
- `Oli.Auditing.PartitionMaintenanceWorker` (new): monthly Oban cron (`"0 8 1 * *"`, 08:00 UTC on the 1st, about 3-4 AM US Eastern) in `config/config.exs` and `config/runtime.exs`. It keeps four future half-years provisioned. With the two-year margin created by the migration, that allows more than 20 runs, and months of `Partitions.status/0` warnings, before a partition could be missing (owner decision: monthly is sufficient).
- `Oli.Auditing.EventExamples` (new, `test/support/`): one canonical example per event type. It is test-only code and is not compiled into the application.
- Migrations own their own SQL and row projections. They must not call `EventCatalog`, `LogEvent`, or any application schema, so later application changes cannot alter what a historical migration does.

## 4. Interfaces & Signatures

### 4.1 Physical schema

Final logical name `audit_log_events`. Inside the migration transaction the new parent is created as `audit_log_events_p` and renamed after the legacy table is dropped. Partition and index names use final names from the start so they need no rename.

```sql
CREATE SEQUENCE audit_events_id_seq AS bigint;

CREATE TABLE audit_log_events_p (
  id                  bigint      NOT NULL DEFAULT nextval('audit_events_id_seq'),
  inserted_at         timestamptz NOT NULL,
  occurred_at         timestamptz,
  schema_version      smallint    NOT NULL,
  event_type          text        NOT NULL,
  outcome             text,
  actor_type          text,
  actor_key           text,
  user_id             bigint,
  author_id           bigint,
  actor_snapshot      jsonb       NOT NULL DEFAULT '{}',
  entity_type         text,
  entity_id           text,
  entity_snapshot     jsonb       NOT NULL DEFAULT '{}',
  affected_user_id    bigint,
  affected_author_id  bigint,
  project_id          bigint,
  section_id          bigint,
  resource_id         bigint,
  institution_id      bigint,
  refs                jsonb       NOT NULL DEFAULT '[]',
  changes             jsonb       NOT NULL DEFAULT '{}',
  details             jsonb       NOT NULL DEFAULT '{}',
  source              text,
  operation_id        uuid,
  parent_operation_id uuid,
  event_key           text,
  legacy_source       text,
  legacy_id           bigint,
  search_text         text        NOT NULL DEFAULT '',
  search_vector       tsvector GENERATED ALWAYS AS (to_tsvector('simple', search_text)) STORED,
  PRIMARY KEY (id, inserted_at)
) PARTITION BY RANGE (inserted_at);
ALTER SEQUENCE audit_events_id_seq OWNED BY audit_log_events_p.id;
```

- `timestamptz` matches the repository's `migration_timestamps: [type: :timestamptz]` and the legacy column (verify in preflight). Partition bounds are written with explicit `+00`, so routing does not depend on the session time zone.
- No foreign keys to accounts, projects, sections, or resources.
- A new sequence is required because `audit_log_events_id_seq` is owned by the legacy table and is dropped with it.
- ID policy (uniform for every legacy source): migrated rows never keep their source ID. They receive new IDs from `audit_events_id_seq` and keep the source ID in `legacy_id`. Before copying, the migration starts the new sequence above the legacy sequence's `last_value` and the legacy `max(id)`. As a result, every new ID, migrated or v2, is greater than every legacy ID, so the rollback can restore legacy IDs without collisions (section 5).

Partitions: `audit_log_events_y<YYYY>h1` covers `[YYYY-01-01 00:00:00+00, YYYY-07-01 00:00:00+00)`, `audit_log_events_y<YYYY>h2` covers `[YYYY-07-01, (YYYY+1)-01-01)`. The migration covers from the interval containing the oldest `inserted_at` of **both** `audit_log_events` and `settings_changes` through the current interval plus four future half-years. When both tables are empty, it starts at the current interval. Including `settings_changes` means the PR-05 conversion never needs to create past partitions; in production that history starts on 2024-07-29 (2024-H2), while `audit_log_events` starts on 2025-12-10. On a deployment around 2026-10 the migration therefore creates nine partitions: 2024-H2 through 2026-H2, plus 2027-H1 through 2028-H2. No default partition.

Indexes (created on the empty parent, so they cascade to partitions):

| Name | Definition |
| --- | --- |
| `audit_events_time_idx` | `(inserted_at DESC, id DESC)` |
| `audit_events_type_time_idx` | `(event_type, inserted_at DESC, id DESC)` |
| `audit_events_project_time_idx` | `(project_id, inserted_at DESC, id DESC) WHERE project_id IS NOT NULL` |
| `audit_events_section_time_idx` | `(section_id, inserted_at DESC, id DESC) WHERE section_id IS NOT NULL` |
| `audit_events_user_time_idx` | `(user_id, inserted_at DESC, id DESC) WHERE user_id IS NOT NULL` |
| `audit_events_author_time_idx` | `(author_id, inserted_at DESC, id DESC) WHERE author_id IS NOT NULL` |
| `audit_events_affected_user_time_idx` | `(affected_user_id, inserted_at DESC, id DESC) WHERE affected_user_id IS NOT NULL` |
| `audit_events_affected_author_time_idx` | `(affected_author_id, inserted_at DESC, id DESC) WHERE affected_author_id IS NOT NULL` |
| `audit_events_parent_operation_idx` | `(parent_operation_id) WHERE parent_operation_id IS NOT NULL` |
| `audit_events_refs_idx` | `GIN (refs jsonb_path_ops)` (containment lookups such as `refs @> '[{"type":"project","id":88}]'`) |
| `audit_events_operation_idx` | `(operation_id, event_key)` (replay lookups across partitions, not a uniqueness guarantee) |
| `audit_events_legacy_idx` | `(legacy_source, legacy_id, inserted_at) WHERE legacy_source IS NOT NULL` |
| `audit_events_search_idx` | `GIN (search_vector)` |

Entity-identity indexes are deferred to PR-07 measurements. There is deliberately no unique index on `(operation_id, event_key)`: with a per-attempt `inserted_at` and per-partition uniqueness it would almost never detect a retry. Duplicate protection is the serialized replay check in each retryable command (PR-02 onwards).

Append-only guard: a row-level `BEFORE UPDATE OR DELETE` trigger on the parent (inherited by every partition) raises `audit_log_events is append-only`, unless the transaction has explicitly run `SET LOCAL oli.audit_log_allow_mutation = 'on'`. Only an explicit, documented procedure sets it (for example, a future personal-data redaction); no application code path does. Dropping or detaching a partition is not a row `DELETE` and is unaffected.

`refs` holds every typed reference that has no dedicated column, as `%{"role", "type", "id", "label"}`. `role` is one of `scope` (where the action applies, e.g. a community or publisher), `source` (origin, e.g. the duplicated project), `previous` / `resulting` (e.g. replaced and new revision, old and new publication), `linked` (e.g. the account linked in `account_linked`), `provider` (e.g. the identity provider). Rule: a project, section, resource, or institution known to the event always goes in its typed column, never only in `refs` or `details` (e.g. `section_created` sets `project_id` to the base project).

Time columns: `inserted_at` is when the row was recorded; it is the partition key and the column used by date filters and sorting. `occurred_at` is when the action happened; it differs only for late-recorded async outcomes, and the UI shows it when it differs. v1 rows keep `occurred_at = NULL` (unknown) rather than copying `inserted_at`.

### 4.2 Database checks

All conditional checks use `schema_version = 1 OR COALESCE(<condition>, false)` so a `NULL` comparison cannot admit an omitted field.

```sql
CHECK (schema_version IN (1, 2))
CHECK (event_type ~ '^[a-z][a-z0-9_]{2,79}$')
CHECK (jsonb_typeof(actor_snapshot) = 'object' AND jsonb_typeof(entity_snapshot) = 'object'
   AND jsonb_typeof(changes) = 'object' AND jsonb_typeof(details) = 'object'
   AND jsonb_typeof(refs) = 'array')

-- v1: provenance mandatory; actor only user/author/unknown; no v2-only fields required.
CHECK (schema_version = 2 OR COALESCE(legacy_source IN ('audit_log_events', 'settings_changes')
   AND legacy_id IS NOT NULL
   AND (actor_type IS NULL OR actor_type IN ('user', 'author', 'unknown'))
   AND actor_key IS NULL, false))

-- v2 envelope.
CHECK (schema_version = 1 OR COALESCE(
       occurred_at IS NOT NULL AND operation_id IS NOT NULL
   AND event_key IS NOT NULL AND length(event_key) BETWEEN 1 AND 200
   AND outcome IN ('succeeded', 'initiated', 'failed', 'canceled', 'partial', 'unknown')
   AND source IN ('ui', 'api', 'mcp', 'job', 'scenario', 'system', 'application')
   AND entity_type ~ '^[a-z][a-z0-9_]{1,63}$' AND length(entity_id) BETWEEN 1 AND 255
   AND legacy_source IS NULL AND legacy_id IS NULL, false))

-- v2 actor exclusivity.
CHECK (schema_version = 1 OR COALESCE(
      (actor_type = 'user'   AND user_id IS NOT NULL AND author_id IS NULL AND actor_key IS NULL)
   OR (actor_type = 'author' AND author_id IS NOT NULL AND user_id IS NULL AND actor_key IS NULL)
   OR (actor_type = 'system' AND actor_key ~ '^[a-z][a-z0-9_]{2,63}$'
       AND user_id IS NULL AND author_id IS NULL), false))

-- v2 affected learner families.
CHECK (schema_version = 1 OR event_type NOT IN (
   'student_exception_created', 'student_exception_updated', 'student_exception_deleted',
   'student_exemption_changed', 'resource_attempt_deleted', 'learner_attempt_reset',
   'manual_grade_changed', 'learner_regraded')
   OR COALESCE(section_id IS NOT NULL AND resource_id IS NOT NULL AND affected_user_id IS NOT NULL, false))
CHECK (schema_version = 1 OR event_type <> 'learner_progress_restored'
   OR COALESCE(section_id IS NOT NULL AND affected_user_id IS NOT NULL, false))

-- v1-only names never appear as v2.
CHECK (schema_version = 1 OR event_type <> 'assessment_setting_changed')
```

Decision for approval (deviation from FDD section 6.3): the DB enforces the event-name format, not the full list of names. The full list is enforced by `Ecto.Enum` and `EventCatalog`. Reason: changing a name-list `CHECK` on a partitioned parent re-validates every partition under a strong lock; later PRs that split an ambiguous action would each need that operation. System actor keys follow the same rule (format in DB, fixed catalog in `Context`). The two learner-family checks above are kept in the DB because they protect the actor-versus-subject invariant and those name sets are stable.

### 4.3 Event contracts

Every v2 event shares this envelope:

| Field | Rule |
| --- | --- |
| Actor | `Context` actor: user, author, or system key from `[:playwright_setup, :provider_provisioning, :scheduled_maintenance]`. `actor_snapshot`: `%{"id", "name", "email"}` for accounts, `%{"key", "label"}` for system |
| Entity | `entity_type` from the contract's allowed list; `entity_id` text: numeric ID, UUID, stable key, or composite `section:<id>/resource:<id>/user:<id>`; `entity_snapshot` from `Snapshot` |
| Scope and references | Required columns per contract; any known project, section, resource, or institution always fills its column; other references go to `refs` with a `role` (section 4.1) |
| Changes | Only the contract's change fields. Record keys: `operation` (`set`, `reset`, `added`, `removed`), `before`, `after`, `effective_before`, `effective_after`, `result_source`, `unit`, `currency`, `redacted`, `changed`. A missing key means not applicable; `null` means explicit null |
| Details | Only the contract's detail keys; values are scalars, lists of scalars, or allowlisted nested maps; serialized size limit 16 KiB per event (larger evidence must use references, not truncation) |
| Outcome | From the contract's allowed outcomes; `succeeded` for synchronous mutations |
| Keys | `event_key` matches `^[a-z0-9_]+(:[a-z0-9_\-]+)*$`; deterministic from the semantic slot, e.g. `account:primary:deleted`, `exception:<user_id>:updated` |
| No-op | `:skip` contracts reject an empty `changes` map with `:no_changes`; `:lifecycle` contracts accept no changes |
| Async | Every asynchronous operation follows one pattern: an `initiated` event, then one terminal event (`succeeded`, `failed`, `canceled`, `partial`, `unknown`) sharing the same `operation_id`; later corrections append a new event. The current status of an operation is its latest event. Rows are never updated |
| Subject consistency | For account and authentication events, `entity_id` equals the `affected_*_id` of the same kind. Composite `entity_id`s are produced only by `Oli.Auditing.EntityId.compose/1` |

Each registry entry is a `%Oli.Auditing.EventCatalog.Contract{}`:

```elixir
%Contract{
  name: :student_exception_updated,
  family: :student_exceptions,
  label: "Student exception updated",
  description:
    "An instructor or admin changed an existing per-student override " <>
      "(dates, attempts, time limit, password) for one assessment.",
  actor_kinds: [:user, :author],
  entity_types: [:student_exception],
  required: [:section_id, :resource_id, :affected_user_id],
  outcomes: [:succeeded],
  no_op: :skip,
  change_fields: AssessmentSettingsPolicy.fields(),
  detail_keys: []
}
```

`family`, `label`, and `description` are required for every entry. `description` is one sentence stating what happened and, where the name could mislead, what it does not imply (e.g. initiation is not completion; `session_revoked` means server-side invalidation).

Family contracts (registry entries mirror this table one-to-one; tests assert both directions):

| Family | Events | entity_type | Required columns | Affected person | Outcomes | Changes / details |
| --- | --- | --- | --- | --- | --- | --- |
| Authentication | `user_logged_in`, `author_logged_in`, `user_logged_out`, `author_logged_out`, `session_revoked` | `user`, `author` | none | matching `affected_*_id` = subject | succeeded | lifecycle; details `auth_method` (enum), `session_ref` (token row ID), `revoked_count`. IP address and user agent are explicitly excluded (owner decision: out of MER-6066 scope and personal-data concerns) |
| Account | `account_created`, `account_updated`, `account_locked`, `account_unlocked`, `account_linked`, `account_permissions_changed`, `account_creation_rights_changed`, `account_recovery_requested`, `account_credential_recovered`, `user_deleted`, `author_deleted`, `author_role_changed`, `account_internal_flag_changed` | `user`, `author` | none | matching `affected_*_id` | succeeded | `:skip` for updates/permissions; profile/access fields from `User`/`Author` changesets; password and email-confirmation fields are `secret`; `refs` role `linked` for the linked account |
| Project | `project_created`, `project_duplicated`, `project_imported`, `project_deleted`, `project_ownership_changed`, `project_collaborator_changed`, `project_published` | `project` | `project_id` | `affected_author_id` for ownership/collaborator | succeeded | details `publication_id`, `version`, `description`, `source_project_id`; collaborator `role`/`status` changes |
| Assessment settings | `assessment_settings_changed`, `assessment_settings_reset`; v1-only `assessment_setting_changed` | `resource` | `section_id`, `resource_id` | none | succeeded | `:skip`; setting keys from assessment settings changesets; `password` is `secret`; reset records `effective_*` and `result_source` |
| Student exceptions | `student_exception_created`, `student_exception_updated`, `student_exception_deleted`, `student_exemption_changed` | `student_exception` | `section_id`, `resource_id`, `affected_user_id` (DB) | `affected_user_id` | succeeded | `:skip` for updates; override fields same policy as assessment settings |
| DOT / activation | `dot_settings_changed`, `activation_settings_changed`, `instructor_ai_recommendation_changed` | `project`, `section`, `resource` | `project_id` or `section_id` | none | succeeded | `:skip`; trigger/condition fields; prompt text as bounded `structured` field |
| Remix | `section_remix_saved` | `curriculum_entry` | `section_id`, `resource_id` | none | succeeded | `:skip`; `parent`, `position`, `hidden`, `source_publication_id` |
| Destructive content | `authoring_content_removed`, `authoring_content_replaced`, `bank_question_deleted`, `media_deleted`, `google_doc_imported` | `resource`, `revision`, `media_item` | `project_id` | none | succeeded, partial, failed | `refs` roles `previous`/`resulting` for replaced and new revisions; import counters as details |
| Discussion | `discussion_post_deleted`, `discussion_thread_deleted`, `discussion_moderated` | `post`, `thread` | `section_id` | `affected_user_id` (post author) when present | succeeded | details `cascade_count`, moderation `status` change; never message body |
| Learner intervention | `resource_attempt_deleted`, `learner_attempt_reset`, `learner_progress_restored`, `manual_grade_changed`, `learner_regraded` | `resource_attempt`, `resource_access`, `enrollment` | `section_id`, `affected_user_id`; `resource_id` except progress restore (DB) | `affected_user_id` | succeeded, partial, failed | score/out_of/attempt_number changes; details `attempt_guid`, `reason` |
| Project settings | `project_settings_changed` | `project` | `project_id` | none | succeeded | `:skip`; keys from project changesets (visibility, duplication, learning model, experiments, tools, surveys, remaining persisted settings) |
| Authoring configuration | `authoring_settings_changed`, `learning_objectives_changed`, `curriculum_changed` | `resource`, `objective`, `container` | `project_id` | none | succeeded | `:skip`; relationship diffs with stable IDs |
| Section lifecycle and settings | `section_created`, `section_deleted`, `section_archived`, `section_settings_changed`, `product_created`, `product_deleted`, `product_archived`, `product_settings_changed`, `blueprint_created`, `blueprint_deleted`, `blueprint_archived`, `blueprint_settings_changed` | `section`, `product`, `blueprint` | `section_id` | none | succeeded | settings `:skip`; details `section_title`, `type`, `base_project_id`, `creation_source`, `copied_groups`, `blueprint_id` |
| Enrollment and access | `invitation_created`, `invitation_accepted`, `enrollment_changed`, `instructor_access_changed` | `invitation`, `enrollment` | `section_id` or `project_id` | `affected_user_id` or `affected_author_id` | succeeded | role/status changes; no invitation token |
| Publication application | `publication_applied`, `publication_update_policy_changed` | `section` | `section_id`, `project_id` | none | succeeded, partial, failed | publication IDs/policy changes |
| Gating and scheduling | `gating_changed`, `prerequisite_changed`, `curriculum_schedule_changed` | `gating_condition`, `section_resource` | `section_id` | `affected_user_id` for student-specific conditions | succeeded | `:skip`; condition/schedule fields |
| Support configuration | `discussion_settings_changed`, `notes_settings_changed`, `student_support_settings_changed` | `section`, `project`, `resource` | `section_id` or `project_id` | none | succeeded | `:skip` |
| Payments | `payment_settings_changed`, `pricing_changed`, `discount_changed`, `payment_code_administered`, `entitlement_changed` | `product`, `section`, `institution`, `discount`, `payment_code_batch`, `enrollment` | `section_id` or `institution_id` | `affected_user_id` for entitlements | succeeded | amounts with `currency`; code batch IDs only, never redeemable codes |
| Certificates | `certificate_settings_changed`, `certificate_granted`, `certificate_revoked` | `certificate`, `granted_certificate` | `section_id` | `affected_user_id` for grant/revoke | succeeded | settings `:skip`; decision state |
| Organizations | `institution_settings_changed`, `community_settings_changed`, `publisher_settings_changed`, `research_consent_settings_changed` | `institution`, `community`, `publisher` | `institution_id` for institution events | none | succeeded | `:skip`; relationship membership changes |
| Integrations | `lms_settings_changed`, `sso_settings_changed`, `lti_settings_changed`, `external_tool_settings_changed`, `roster_settings_changed`, `grade_passback_settings_changed` | `registration`, `deployment`, `external_tool`, `institution`, `section` | `institution_id` or `section_id` | none | succeeded | `:skip`; keys, secrets, JWKS, launch payloads are `secret` or excluded |
| AI and credentials | `ai_service_settings_changed`, `credential_lifecycle_changed` | `ai_service`, `api_key`, `mcp_token` | none | `affected_author_id` for owner when different | succeeded | lifecycle enum `created/rotated/enabled/disabled/revoked`; no credential value or hash |
| Feature flags | `feature_flag_enabled`, `feature_flag_disabled`, `feature_flag_removed`, `feature_rollout_stage_changed`, `feature_rollout_stage_deleted`, `feature_rollout_exemption_upserted`, `feature_rollout_exemption_deleted` | `feature_flag`, `feature_rollout`, `rollout_exemption` | none | none | succeeded | existing detail keys preserved (`feature_name`, `resource_type`, `scope_type`, `stage`, `previous`, `effect`, `publisher_id`, `note`) |
| Administrative operations | `administrative_operation`, `clickhouse_admin_operation_initiated`, `clickhouse_admin_operation_outcome` | `administrative_operation`, `clickhouse_operation` | none | none | initiated (initiated event only), succeeded, failed, canceled, partial, unknown | details `kind`, `operation_label`, safe result summary, `job_ref` |
| Preferences | `preferences_changed` | `user`, `author` | none | matching `affected_*_id` | succeeded | `:skip`; persisted preference keys only |

Catalog evolution rules: an event name is never removed or renamed once released, because stored rows must stay readable through `Ecto.Enum`; an obsolete name is marked `deprecated: true` and rejected for new writes. `changes` and `details` keys are only ever added to a contract; changing a key's meaning requires a new key.

Field-level lists marked "from changesets" are produced in checkpoint A (section 5) and reviewed before the migrations are written. They do not change the DDL because `changes` and `details` are validated in the application.

### 4.4 Application API

```elixir
@spec Oli.Auditing.Context.for_actor(User.t() | Author.t(), keyword()) :: Context.t()
# opts: source: :ui | :api | :mcp | :job | :scenario | :application (required),
#       operation_id: Ecto.UUID.t() (default: generated), parent_operation_id: Ecto.UUID.t() | nil

@spec Oli.Auditing.Context.for_system(:playwright_setup | :provider_provisioning | :scheduled_maintenance, keyword()) :: Context.t()
# raises FunctionClauseError for any other key; source defaults to :system

@type proposal_attrs :: %{
        required(:event_type) => atom(),
        required(:entity) => {entity_type :: atom(), entity_id :: term(), snapshot :: map()},
        required(:event_key) => String.t(),
        optional(:outcome) => atom(),
        optional(:affected) => {:user | :author, pos_integer()},
        optional(:scope) => %{optional(:project_id | :section_id | :resource_id | :institution_id) => pos_integer()},
        optional(:refs) => [%{role: atom(), type: atom(), id: term(), label: String.t()}],
        optional(:changes) => map(),
        optional(:details) => map(),
        optional(:occurred_at) => DateTime.t()
      }

@spec Oli.Auditing.build(Context.t(), proposal_attrs()) ::
        {:ok, Ecto.Changeset.t()} | {:error, :no_changes | Ecto.Changeset.t()}

@spec Oli.Auditing.append(Ecto.Multi.t(), Ecto.Multi.name(), (map() -> {:ok, Ecto.Changeset.t()} | {:error, term()} | :skip)) ::
        Ecto.Multi.t()
# runs the builder with prior Multi results; :skip appends nothing (no-op); errors roll back the Multi

@spec Oli.Auditing.insert(Ecto.Changeset.t()) :: {:ok, LogEvent.t()} | {:error, Oli.Auditing.Error.t()}

# Legacy adapter; signature unchanged for existing callers.
@spec Oli.Auditing.capture(User.t() | Author.t() | nil, atom(), struct() | nil, map()) ::
        {:ok, LogEvent.t()} | {:error, Oli.Auditing.Error.t() | Ecto.Changeset.t()}

@spec Oli.Auditing.get_event!(pos_integer()) :: LogEvent.t()                 # where id == ^id, Repo.one!
@spec Oli.Auditing.get_event!(pos_integer(), DateTime.t()) :: LogEvent.t()   # exact partition lookup
@spec Oli.Auditing.browse_events(Paging.t(), Sorting.t(), BrowseOptions.t()) :: [LogEvent.t()]

@spec Oli.Auditing.Partitions.ensure_through(Date.t()) ::
        {:ok, %{created: [String.t()], covered_through: Date.t()}} | {:error, Oli.Auditing.Error.t()}
@spec Oli.Auditing.Partitions.status() ::
        {:ok | :warning | :error, %{covered_through: Date.t() | nil, current: String.t(), future_intervals: non_neg_integer()}}
```

`Oli.Auditing.Error` is `%{code: :invalid_event | :no_changes | :partition_missing | :insert_failed, event_type: atom(), correlation_id: Ecto.UUID.t()}`. It never contains the rejected changeset values. `capture/4` keeps returning `{:error, changeset}` for validation errors so existing callers that pattern-match on it keep working, but the changeset is built from the safe projection, not from raw input.

`LogEvent` uses `@primary_key false`, `field :id, :id, primary_key: true, read_after_writes: true`, `field :inserted_at, :utc_datetime_usec, primary_key: true` (set by `build/2`, not `timestamps/1`), and `field :event_type, Ecto.Enum, values: EventCatalog.names()`. It has no `schema_version` in its cast list; `v2_changeset/2` forces `2`.

Legacy adapter mapping (all `source: :application`, fresh `operation_id`, `outcome: :succeeded` except initiation):

| Event | entity | event_key | Extra mapping |
| --- | --- | --- | --- |
| `user_deleted`, `author_deleted` | resource struct as `user`/`author` | `account:primary:deleted` | `affected_*_id`; snapshot from struct before deletion |
| `author_role_changed`, `account_internal_flag_changed` | resource struct | `account:primary:<event>` | `affected_*_id`; `previous`/`new` values copied into `changes` and existing detail keys kept |
| `project_published`, `google_doc_imported` | `project` | `project:<id>:<event>` | `project_id`; Google import also `resource_id` from `page_resource_id` |
| `section_created` | `section` | `section:<id>:created` | `section_id` |
| `resource_attempt_deleted` | `resource_attempt` from `attempt_guid` | `attempt:<guid>:deleted` | `section_id`, `resource_id`, `affected_user_id` from details |
| feature flag events | `feature_flag` from `feature_name` | `flag:<name>:<event>` | `project_id`/`section_id` when resource is a project/section; otherwise system-wide scope ref |
| rollout events | `feature_rollout`/`rollout_exemption` | `rollout:<feature>:<scope>:<event>` | scope in `refs` with role `scope` |
| `clickhouse_admin_operation_initiated` | `clickhouse_operation` from details `operation_id` | `clickhouse:<kind>:initiated` | `outcome: :initiated` |

A `nil` actor returns `{:error, %Error{code: :invalid_event}}`; the adapter never invents a system actor. Callers that currently skip nil actors keep doing so.

### 4.5 Migrations

Primary path: one migration, `migrate_audit_log_events_to_partitioned`, generated with `mix ecto.gen.migration`. It runs inside Ecto's normal DDL transaction with the default migration lock, so `Oli.Repo` configuration is unchanged. Everything in `up/0` commits together or not at all. A failure at any step, including reconciliation, rolls back the whole migration, leaves the legacy table untouched, and fails `bin/migrate`.

Production volume (measured by operations on 2026-10-29): `audit_log_events` has 6,269 rows / 3.7 MB, from 2025-12-10 to 2026-10-29. A transactional copy of that size takes about a second, so this path is confirmed for PR-01. Plan B (section 4.7) remains documented only as a fallback if rehearsal shows `up/0` or `down/0` above 60 seconds.

Note for PR-05: `settings_changes` has 439,180 rows / 58 MB in production (2024-07-29 to 2026-10-29). That conversion is not part of this PR. Its own design must rehearse a single `INSERT ... SELECT` with a SQL-only projection against the 60-second threshold before choosing between a single transaction and plan B.

`up/0`, in order, all inside the migration transaction:

1. `SET LOCAL lock_timeout = '5s'`; `LOCK TABLE audit_log_events IN ACCESS EXCLUSIVE MODE`. Writers to the legacy table wait or fail fast; no row can be added during the copy.
2. Create `audit_events_id_seq` starting above the legacy `max(id)` and the legacy sequence `last_value`.
3. Create `audit_log_events_p`, its partitions (section 4.1 range, including `settings_changes`), indexes, checks, and column comments (section 4.6).
4. If `audit_log_events_rollback_archive` exists (roll-forward after a rollback), insert its rows first with all columns unchanged.
5. Copy the legacy rows as v1 using the projection below, in ascending source `id` order. Legacy rows already represented in the archive are skipped: those whose `id` equals an archived v1 `legacy_id` or an archived v2 `id`. Rows are read and transformed in the migration module and inserted in chunks of 1,000 only to respect the PostgreSQL parameter limit; the chunks share the single transaction.
6. Reconcile (below). Any mismatch raises.
7. Copy grants from the legacy table's ACL when it differs from the new table's; drop `audit_log_events` (this also drops its owned sequence); `ALTER TABLE audit_log_events_p RENAME TO audit_log_events`; drop `audit_log_events_rollback_archive` if it exists.
8. Print a one-line summary: counts per event type, redaction counts by key, rows with ambiguous actors. Never values.

`down/0`, also one transaction:

1. `SET LOCAL lock_timeout = '5s'`; `LOCK TABLE audit_log_events IN ACCESS EXCLUSIVE MODE`.
2. `CREATE TABLE audit_log_events_rollback_archive AS SELECT` every column except `search_vector` from the partitioned table. The archive is nonpartitioned and holds the complete safe history, including types the old code does not know.
3. Create `audit_log_events_restore` with the original 2025 DDL and index names, and insert only rows whose `event_type` is one of the original 16:
   - v1 rows under their `legacy_id`, with `resource_id` restored from `details.legacy_resource_ref`;
   - v2 rows under their own `id`, mapped back to the legacy columns.
   The two ID ranges cannot collide because every new ID is above the legacy maximum. No secret values are restored; sanitized details stay sanitized.
4. Drop the partitioned table and its sequence; rename `audit_log_events_restore` to `audit_log_events`; set its `id` sequence above the largest ID in the archive.

The old UI cannot show events of new types until roll-forward. Running `up/0` again restores them from the archive (step 4) without duplicates.

Copy projection, implemented inside the migration module (no application schemas):

| Target | Source rule |
| --- | --- |
| `id` | new value from `audit_events_id_seq`, assigned in ascending source `id` order so original ordering is preserved |
| `inserted_at`, `event_type`, `user_id`, `author_id`, `project_id`, `section_id` | copied unchanged |
| `schema_version`, `legacy_source`, `legacy_id` | `1`, `'audit_log_events'`, source `id` |
| `actor_type` | `user` if only `user_id`; `author` if only `author_id`; `unknown` if neither. If both IDs are present (not producible by the current application, only by manual SQL), both IDs are kept, `actor_type` is `unknown`, and the row is counted as ambiguous in the summary; the migration does not fail |
| `outcome` | `initiated` for `clickhouse_admin_operation_initiated`; otherwise `NULL` (unknown) |
| `entity_type`, `entity_id`, `affected_*_id` | `details.resource_type` of `Elixir.Oli.Accounts.User`/`Author` with `resource_id` maps to `user`/`author` entity and affected ID; `section_created` maps to `section`; `project_published` maps to `project`; otherwise `NULL` |
| `resource_id` | `NULL`; legacy value kept as `details.legacy_resource_ref = {"id", "type"}` because legacy rows used it for non-resource IDs |
| `details` | recursive sanitizer: keys matching `password|secret|token|credential|api_key|private_key|authorization|cookie` (case-insensitive) become `{"redacted": true}`; everything else preserved |
| `search_text` | safe identity values already in details: `email`, `name`, `project_title`, `section_title`, `page_title`, `feature_name`, `author_name`, `author_email`, `actor_name`; never current-record joins |
| `actor_snapshot`, `entity_snapshot`, `occurred_at`, `source`, `operation_id`, `event_key` | empty/`NULL` (unknown) |

A row outside every provisioned partition makes the insert fail and the whole migration roll back; no row is skipped.

Reconciliation, inside the transaction before the legacy table is dropped:
- every legacy row is either copied or represented in the archive, and vice versa (anti-joins between legacy `id` and destination `legacy_id`, plus archived v2 `id`s);
- ascending source `id` maps to ascending new `id`;
- equal checksum of `md5(string_agg(legacy_id || inserted_at || event_type || user_id || author_id || project_id || section_id, ',' ORDER BY legacy_id))` on both sides;
- recomputing the sanitizer per row matches the stored `details`.

### 4.6 Event documentation

Columns and event contracts must be understandable without reading this design. Documentation is generated or checked by tests so it cannot drift from the catalog.

- **Database:** the migration adds `COMMENT ON COLUMN` for every column of `audit_log_events_p`: one line with its meaning and allowed values (e.g. `source`: "where the change originated: ui, api, mcp, job, scenario, system, application"). Comments survive the final rename.
- **Schema:** the `Oli.Auditing.LogEvent` `@moduledoc` contains the field glossary and three worked examples: a bulk student-exception update, a system-provisioned account, and a migrated v1 row.
- **Examples:** `Oli.Auditing.EventExamples` (`test/support/audit/event_examples.ex`) defines one realistic example per event type, with every column value set as the contract expects. It is the single source for the contract tests and the generated reference. A catalog entry without an example fails the suite.
- **Generated reference:** `Oli.Auditing.EventReference.render/0` (test support) combines `EventCatalog` and `EventExamples` into `docs/design-docs/audit-log-events.md`. That file contains the column glossary, the family table, and for each event type: family, label, description, allowed actors, required columns, allowed `changes`/`details` keys, outcomes, no-op policy, and the example row. `test/support/audit_log_event_reference.exs` regenerates it; `event_reference_test.exs` fails when the committed file is stale.

Later PRs that add or change an event must update the catalog, its example, and the regenerated reference in the same PR.

### 4.7 Plan B: batched migration

Use only if rehearsal at production volume shows `up/0` or `down/0` above 60 seconds. It keeps the same schema, projection, ID policy, and reconciliation, and changes only how the work is executed:

- Four migrations: create, copy, swap, retire. The copy runs in independently committed batches using keyset pagination on source `id`, and resumes from `max(legacy_id)` already copied.
- `Oli.Repo` switches to `migration_lock: :pg_advisory_lock`. Ecto's default `:table_lock` wraps the whole migration run in one transaction (`deps/ecto_sql/lib/ecto/adapters/postgres.ex`), which would prevent batches from committing separately. This follows the owner-supplied Safe Ecto Migrations guide.
- `Oli.Release.migrate/0` stops before the retire migration. After a smoke check with the new application while traffic is paused, an operator runs a readiness command that reconciles and then retires the legacy table, within the same deployment.
- Rollback archives in batches before rebuilding the legacy table.

Adopting plan B requires owner approval at that time, with the rehearsal numbers.

## 5. Data Flow & Edge Cases

- Main flow (implementation, internal review checkpoints within PR-01):
  1. Checkpoint A, contracts: `Context`, `EventCatalog`, `Changes`, `Snapshot`, field-key lists from domain changesets, `EventExamples` and the generated `docs/design-docs/audit-log-events.md`. Review before DDL; the generated reference is the review artifact for the contracts.
  2. Checkpoint B, storage: the migration's create step, v2 `LogEvent`, `build/append/insert`, legacy adapter, readers, partitions module and worker. Existing regression tests pass on the new table.
  3. Checkpoint C, migration: copy, reconciliation, swap, `down/0`, roll-forward, rehearsal script; rehearsal evidence recorded.
  4. Checkpoint D, evidence: benchmark, oldest-partition removal rehearsal, operating procedure, `evidence/pr-01-storage.md`.
- Deployment procedure (in the eventual single integration deployment):
  1. Preflight (read-only SQL in the runbook): row counts and min/max `inserted_at` of `audit_log_events` and `settings_changes`, rows with both actor IDs, rows with neither, `resource_type` distribution, sanitizer key hits, table sizes, PostgreSQL version, app-role privileges (`CREATE` on schema, for the partition worker), ACL of `audit_log_events`.
  2. Stop all old application instances and Oban before migrating. An old binary cannot write to the new table: its inserts violate the v2 checks and, for section creation, roll back the user's operation.
  3. `bin/migrate` runs `Oli.Release.migrate/0` as today. The single migration creates, copies, reconciles, swaps, and retires the legacy table in one transaction. If anything fails, nothing changes and the deployment stops.
  4. Start the new application. Smoke: open `/admin/audit_log`, `Partitions.status/0` is `:ok`.
- Rollback procedure:
  - `Oli.Release.rollback(Oli.Repo, <version before the migration>)` with the new application stopped runs `down/0` (section 4.5): archive everything, rebuild the legacy table with the original 16 types, and drop the partitioned table, all in one transaction.
  - Roll-forward: deploying again reruns `up/0`. It restores the archive first, copies only the legacy rows written by the old binary after rollback, and drops the archive after reconciliation.
  - Pending Oban jobs are drained or paused before rollback. PR-01 adds no job types whose arguments an old binary cannot run.
- Edge cases:
  - Event exactly at `2026-07-01 00:00:00.000000+00` routes to `y2026h2`; `2026-06-30 23:59:59.999999+00` routes to `y2026h1`.
  - Missing partition: PostgreSQL raises `no partition of relation` (SQLSTATE `23514`). `insert/1` and `append/3` translate it to `%Error{code: :partition_missing}`, roll back the Multi, log one safe line (`event_type`, interval, correlation ID), and emit telemetry `[:oli, :auditing, :append, :error]`. Existing `capture/4` callers keep their current handling.
  - Legacy row with neither actor stays `actor_type = 'unknown'`, never `system`.
  - Legacy row with both actor IDs: both IDs are kept, `actor_type = 'unknown'`, counted as ambiguous in the summary. The current application cannot produce it (`capture/4` sets only one ID from the actor struct); only manual SQL could.
  - Legacy `details` with a sanitizer hit: value replaced by the marker, counted in the summary.
  - Migration interrupted at any point (crash, lock timeout, reconciliation mismatch): the transaction rolls back completely and the legacy table remains the logical table; rerunning starts from scratch.
  - A `settings_changes` row older than every `audit_log_events` row: covered because the partition range starts at the oldest timestamp of both tables.
  - Concurrent `ensure_through/1` calls: `pg_try_advisory_xact_lock(hashtext('oli.audit_log_events.partitions'))`; the loser returns the current report without DDL. Each `CREATE TABLE ... PARTITION OF` runs with `lock_timeout = '5s'` and is idempotent by catalog lookup.
  - Partition names come only from `Date` values through `Partitions.name_for/1`; no request input reaches identifiers.
  - Duplicate `(operation_id, event_key)` in the same microsecond: rejected by the partial unique index. Across partitions it is not rejected by the DB; replay protocols are PR-02+.
  - Builder input containing secret keys outside the contract: rejected with `:invalid_event`; the error lists field names only.
  - Test environment: migrations provision through current plus four half-years. `test/test_helper.exs` calls `Partitions.ensure_through/1` for today plus two years, so the suite does not depend on when the DB was migrated. Partition DDL tests run `async: false`.

## 6. Test Plan

- Unit or component tests:
  - `test/oli/auditing/event_catalog_test.exs`: the registry equals the section 4.3 table; every name has a family, label, non-empty description, outcomes, and entity types; `LogEvent` enum equals `EventCatalog.names()`.
  - `test/oli/auditing/contracts_test.exs`: iterates `EventCatalog.names()`. Fails if an event has no entry in `EventExamples`. For each example, it inserts the row and reads it back, then rejects the variants derived from the contract: each required column removed, missing affected person, wrong entity type, disallowed actor kind or outcome, unknown change field, unknown detail key, and empty changes for `:skip`. Rejections are asserted through the changeset and, for DB-enforced invariants, through raw SQL.
  - `test/oli/auditing/event_reference_test.exs`: the committed `docs/design-docs/audit-log-events.md` equals the output of `Oli.Auditing.EventReference.render/0`. It is regenerated with `MIX_ENV=test mix run test/support/audit_log_event_reference.exs`, which needs no database.
  - Cases explicitly included: multi-field change, reset with effective values, secret marker, deleted target snapshot, system actor, bulk (several events sharing an operation ID with distinct keys), async initiated plus terminal outcome, student exception actor versus student.
  - `test/oli/auditing/append_only_test.exs`: `UPDATE` and `DELETE` on any partition raise; they succeed only inside a transaction that sets `oli.audit_log_allow_mutation`; detaching a partition still works.
  - Subject consistency: for every account and authentication example, `entity_id` equals the `affected_*_id`; composite IDs round-trip through `EntityId.compose/1`.
  - Catalog evolution: a stored snapshot of released event names (`test/support/audit/released_event_names.txt`) must remain a subset of `EventCatalog.names()`.
  - `test/oli/auditing/context_test.exs`: unknown system keys raise; no version or skip option is accepted.
  - `test/oli/auditing/changes_test.exs` and `snapshot_test.exs`: missing versus null versus redacted; nested secret keys rejected; snapshot allowlist.
  - `test/oli/auditing/constraints_test.exs`: raw SQL inserts violating each check fail; legitimate v1 nulls pass; v2 with `legacy_source` fails; v1 without provenance fails.
- Integration tests:
  - Existing `test/oli/auditing_test.exs`, `test/oli_web/live/admin/audit_log_live_test.exs`, `test/oli/delivery/section_creation_test.exs` pass unchanged except where they assert the old struct shape (adapted, behavior kept).
  - `test/oli/auditing/legacy_adapter_test.exs`: each of the 16 producers writes one v2 row with the mapped entity, scope, affected person, and outcome; nil actor is rejected.
  - `test/oli/auditing/partitions_test.exs`: boundary routing, `ensure_through/1` idempotency and concurrency, missing-partition error and telemetry, `status/0` warning threshold.
  - `test/oli/auditing/partition_maintenance_worker_test.exs`: worker calls `ensure_through/1`; both cron configs include it (assert config).
  - `test/oli_web/live/admin/audit_log_live_test.exs` additions: a v1 unknown-actor row, a system-actor row, and one row of each new family render without crashing; no `schema_version` text or secret marker value in HTML.
  - Fresh test databases: the migration runs on empty legacy tables during the normal `ecto.migrate` bootstrap, creating the current-interval partitions and dropping the empty legacy table.
  - Secret markers: a unique marker string in builder input never appears in persisted JSON, `search_text`, error structs, or captured logs.
- Manual checks:
  - `test/support/audit_log_migration_rehearsal.exs` on a newly created disposable database (refuses to reuse one), following `test/support/secure_delivery_migration_check.exs`: original 2025 table plus synthetic rows (both actor types, neither, both IDs, struct resource types, secret-named keys, boundary timestamps, IDs with gaps, `settings_changes` rows older than every audit row); `up/0`; a forced reconciliation failure that leaves the legacy table intact; immediate rollback; rollback after inserting new-type v2 events; roll-forward; records `up/0` and `down/0` duration (plan B threshold: 60 seconds at production volume), locks held, WAL bytes (`pg_current_wal_lsn` diff), table/index sizes.
  - `test/support/audit_log_partition_benchmark.exs`: six-month versus annual layouts at 1M and 10M synthetic rows over five years. The volume baseline comes from production on 2026-10-29: about 600 central events per month and about 16,000 `settings_changes` rows per month, roughly 200,000 rows per year if all assessment history were central. 1M and 10M are labeled growth scenarios (about 5x and 50x that rate), not measurements; single and 1,000-row insert latency, date-bounded and all-history first-page queries with `EXPLAIN (ANALYZE, BUFFERS)`; partition pruning visible.
  - Oldest-partition removal: `ALTER TABLE ... DETACH PARTITION ... CONCURRENTLY` then `DROP` on the disposable DB; newer partitions unaffected.
  - Planned commands, run only after verifying the isolated test DB and URL precedence (escalated permissions per `AGENTS.md`): `mix format --check-formatted`; `mix compile --warnings-as-errors`; `mix test test/oli/auditing_test.exs test/oli_web/live/admin/audit_log_live_test.exs test/oli/delivery/section_creation_test.exs test/oli/auditing`; full `mix test` because `test/test_helper.exs` changes; `MIX_ENV=test mix run test/support/audit_log_migration_rehearsal.exs`.

## 7. Risks & Open Questions

- Risks:
  - Production volume makes the single transaction too long (above 60 seconds in rehearsal). Mitigation: plan B (section 4.7), with owner approval and rehearsal numbers.
  - An old application instance writes during or after the migration. Mitigation: the deployment stops old instances first (section 5); during the migration the legacy table is locked, so a late write waits or fails rather than being lost silently.
  - App role lacks `CREATE` in production, so the worker cannot provision partitions. Mitigation: the migration provisions two years ahead; `Partitions.status/0` reports the horizon; operators run `ensure_through/1` with the migration role if needed.
  - Reader assumptions about `inserted_at` precision (`:utc_datetime` to `:utc_datetime_usec`) break tests or display. Mitigation: adapt display formatting; covered by LiveView tests.
  - PR-01 cannot deploy alone; the integration branch holds it until all PRs pass. Recorded in evidence; no intermediate deploy.
  - Personal data (name, email) is copied into snapshots and `search_text`. `search_text` is built only from snapshot fields so a future erasure procedure can rewrite both consistently; that procedure is out of scope here.
  - Impersonation: verified at `ddb2d80c3e` that production Torus has no "act as another account" feature. A masquerade capability is only referenced by preview-only QA tooling (`lib/oli/preview_qa_tools/config.ex`) and has no route in the router. If one is added later, the envelope needs a "real principal" field before it ships.
- Open questions:
  - Operations inputs needed before release (not before implementation): PostgreSQL version, app-role privileges, and how `bin/migrate` runs relative to stopping old instances.

## 8. Definition of Done

- [x] Requirement coverage is explicit
- [x] Interfaces are concrete
- [x] Test plan covers main and edge paths
- [x] Validation passes
- [x] Owner approves schema, contracts, and migration/retirement/rollback procedure (plan Phase 1 gate)
