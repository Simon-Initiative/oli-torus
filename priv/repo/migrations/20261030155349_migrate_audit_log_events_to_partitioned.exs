defmodule Oli.Repo.Migrations.MigrateAuditLogEventsToPartitioned do
  @moduledoc """
  Replaces the flat `audit_log_events` table with a table partitioned by half-year on
  `inserted_at` that enforces the versioned event envelope.

  This migration owns its SQL: it must not call `Oli.Auditing.EventCatalog`,
  `Oli.Auditing.LogEvent`, `Oli.Auditing.Partitions`, or any other application module, so later
  application changes cannot alter what it does.

  Copying existing rows as `schema_version = 1` history is not implemented yet. Until it is, `up/0`
  refuses to run when the legacy table has rows, and `down/0` refuses to run when the
  partitioned table has rows, so no history is ever dropped.
  """

  use Ecto.Migration

  @future_intervals 4

  @columns [
    id: "Event ID from audit_events_id_seq; unique together with inserted_at",
    inserted_at:
      "When the row was recorded (UTC); partition key, used for date filters and sorting",
    occurred_at:
      "When the action happened; differs from inserted_at only for late async outcomes; NULL on v1 rows (unknown)",
    schema_version:
      "1: migrated history with unknowns allowed; 2: application events with the full envelope",
    event_type: "Catalog event name (Oli.Auditing.EventCatalog)",
    outcome:
      "succeeded, initiated, failed, canceled, partial, or unknown; NULL on v1 rows (unknown)",
    actor_type: "user, author, system, or unknown (v1 only)",
    actor_key: "System actor key when actor_type is system; NULL otherwise",
    user_id: "Acting user ID when actor_type is user (no foreign key)",
    author_id: "Acting author ID when actor_type is author (no foreign key)",
    actor_snapshot:
      "Actor identity at the time of the event: id, name, email for accounts; key, label for system actors",
    entity_type: "Kind of record the event is about, such as section or student_exception",
    entity_id: "ID of that record; composite IDs look like section:301/resource:4512/user:77",
    entity_snapshot: "Allowlisted identity of the entity at the time of the event",
    affected_user_id: "Learner or user the action was applied to, when different from the actor",
    affected_author_id: "Author the action was applied to, when different from the actor",
    project_id: "Project scope (no foreign key)",
    section_id: "Section scope (no foreign key)",
    resource_id: "Course resource scope (no foreign key); NULL on v1 rows",
    institution_id: "Institution scope (no foreign key)",
    refs:
      "Typed references without a dedicated column: role (scope, source, previous, resulting, linked, provider), type, id, label",
    changes:
      "Per-field change records: operation, before, after, effective_before, effective_after, result_source, unit, currency; secrets only record redacted and changed",
    details: "Event-specific allowlisted context; at most 16 KiB",
    source: "Where the change originated: ui, api, mcp, job, scenario, system, application",
    operation_id: "Groups the events written by one command",
    parent_operation_id: "Operation that started this one, for async and nested work",
    event_key: "Identifies the event within its operation, such as section:301:updated",
    legacy_source: "Table a v1 row was migrated from: audit_log_events or settings_changes",
    legacy_id: "Row ID in the legacy source table",
    search_text: "Text indexed for search, built only from snapshots and reference labels",
    search_vector: "Generated full-text vector of search_text"
  ]

  def up do
    execute("SET LOCAL lock_timeout = '5s'")
    execute("LOCK TABLE audit_log_events IN ACCESS EXCLUSIVE MODE")
    # execute/1 only queues commands; flush so the lock is held before the reads below.
    flush()

    refuse_unless_empty("audit_log_events")

    execute("""
    CREATE SEQUENCE audit_events_id_seq AS bigint START WITH #{next_id()}
    """)

    create_parent()
    create_append_only_guard()
    Enum.each(partitions(), &create_partition/1)
    create_indexes()
    comment_columns()

    execute("DROP TABLE audit_log_events")
    execute("ALTER TABLE audit_log_events_p RENAME TO audit_log_events")
  end

  def down do
    execute("SET LOCAL lock_timeout = '5s'")
    execute("LOCK TABLE audit_log_events IN ACCESS EXCLUSIVE MODE")
    # execute/1 only queues commands; flush so the lock is held before the reads below.
    flush()

    refuse_unless_empty("audit_log_events")

    execute("DROP TABLE audit_log_events")
    execute("DROP FUNCTION audit_log_events_append_only()")

    execute("""
    CREATE TABLE audit_log_events (
      id bigserial PRIMARY KEY,
      user_id integer,
      author_id integer,
      event_type varchar(255) NOT NULL,
      section_id integer,
      project_id integer,
      resource_id integer,
      details jsonb DEFAULT '{}'::jsonb,
      inserted_at timestamptz NOT NULL
    )
    """)

    for column <- ~w(user_id author_id section_id project_id event_type inserted_at) do
      execute("CREATE INDEX audit_log_events_#{column}_index ON audit_log_events (#{column})")
    end
  end

  defp refuse_unless_empty(table) do
    %{rows: [[count]]} = repo().query!("SELECT count(*) FROM #{table}")

    case count do
      0 ->
        :ok

      _ ->
        raise "#{table} has #{count} rows; copying history between layouts is not implemented yet"
    end
  end

  # Every new ID is above every legacy ID, so a rollback can restore legacy IDs without collisions.
  defp next_id do
    %{rows: [[max_id]]} = repo().query!("SELECT COALESCE(max(id), 0) FROM audit_log_events")

    %{rows: [[last_value]]} =
      repo().query!("SELECT COALESCE(last_value, 0) FROM audit_log_events_id_seq")

    max(max_id, last_value) + 1
  end

  defp create_parent do
    execute("""
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
      PRIMARY KEY (id, inserted_at),

      CONSTRAINT audit_events_schema_version_check CHECK (schema_version IN (1, 2)),
      CONSTRAINT audit_events_event_type_format_check
        CHECK (event_type ~ '^[a-z][a-z0-9_]{2,79}$'),
      CONSTRAINT audit_events_json_shape_check CHECK (
        jsonb_typeof(actor_snapshot) = 'object' AND jsonb_typeof(entity_snapshot) = 'object'
        AND jsonb_typeof(changes) = 'object' AND jsonb_typeof(details) = 'object'
        AND jsonb_typeof(refs) = 'array'),

      CONSTRAINT audit_events_v1_provenance_check CHECK (schema_version = 2 OR COALESCE(
        legacy_source IN ('audit_log_events', 'settings_changes')
        AND legacy_id IS NOT NULL
        AND (actor_type IS NULL OR actor_type IN ('user', 'author', 'unknown'))
        AND actor_key IS NULL, false)),

      CONSTRAINT audit_events_v2_envelope_check CHECK (schema_version = 1 OR COALESCE(
        occurred_at IS NOT NULL AND operation_id IS NOT NULL
        AND event_key IS NOT NULL AND length(event_key) BETWEEN 1 AND 200
        AND outcome IN ('succeeded', 'initiated', 'failed', 'canceled', 'partial', 'unknown')
        AND source IN ('ui', 'api', 'mcp', 'job', 'scenario', 'system', 'application')
        AND entity_type ~ '^[a-z][a-z0-9_]{1,63}$' AND length(entity_id) BETWEEN 1 AND 255
        AND legacy_source IS NULL AND legacy_id IS NULL, false)),

      CONSTRAINT audit_events_v2_actor_check CHECK (schema_version = 1 OR COALESCE(
        (actor_type = 'user' AND user_id IS NOT NULL AND author_id IS NULL AND actor_key IS NULL)
        OR (actor_type = 'author' AND author_id IS NOT NULL AND user_id IS NULL
            AND actor_key IS NULL)
        OR (actor_type = 'system' AND actor_key ~ '^[a-z][a-z0-9_]{2,63}$'
            AND user_id IS NULL AND author_id IS NULL), false)),

      CONSTRAINT audit_events_v2_learner_check CHECK (schema_version = 1 OR event_type NOT IN (
        'student_exception_created', 'student_exception_updated', 'student_exception_deleted',
        'resource_attempt_deleted', 'learner_attempt_reset',
        'manual_grade_changed', 'learner_regraded')
        OR COALESCE(section_id IS NOT NULL AND resource_id IS NOT NULL
          AND affected_user_id IS NOT NULL, false)),

      CONSTRAINT audit_events_v2_progress_restore_check CHECK (schema_version = 1
        OR event_type <> 'learner_progress_restored'
        OR COALESCE(section_id IS NOT NULL AND affected_user_id IS NOT NULL, false)),

      CONSTRAINT audit_events_v1_only_names_check CHECK (schema_version = 1
        OR event_type <> 'assessment_setting_changed')
    ) PARTITION BY RANGE (inserted_at)
    """)

    execute("ALTER SEQUENCE audit_events_id_seq OWNED BY audit_log_events_p.id")
  end

  # From the half-year holding the oldest row of audit_log_events or settings_changes (the
  # current one when both are empty) through the current half-year plus four future ones.
  defp partitions do
    %{rows: [[oldest]]} =
      repo().query!("""
      SELECT least(
        (SELECT min(inserted_at) FROM audit_log_events),
        (SELECT min(inserted_at) FROM settings_changes))
      """)

    today = Date.utc_today()
    first = interval_start((oldest && DateTime.to_date(to_utc(oldest))) || today)
    last = today |> interval_start() |> Date.shift(month: 6 * @future_intervals)

    first
    |> Stream.iterate(&Date.shift(&1, month: 6))
    |> Enum.take_while(&(Date.compare(&1, last) != :gt))
  end

  defp to_utc(%DateTime{} = value), do: value
  defp to_utc(%NaiveDateTime{} = value), do: DateTime.from_naive!(value, "Etc/UTC")

  defp interval_start(%Date{year: year, month: month}) when month < 7, do: Date.new!(year, 1, 1)
  defp interval_start(%Date{year: year}), do: Date.new!(year, 7, 1)

  defp create_partition(%Date{year: year} = from) do
    half = half(from)
    to = Date.shift(from, month: 6)

    name = "audit_log_events_y#{year}#{half}"

    execute("""
    CREATE TABLE #{name} PARTITION OF audit_log_events_p
      FOR VALUES FROM ('#{Date.to_iso8601(from)} 00:00:00+00') TO ('#{Date.to_iso8601(to)} 00:00:00+00')
    """)

    # Statement triggers are not inherited, so each partition blocks TRUNCATE itself.
    execute("""
    CREATE TRIGGER audit_log_events_no_truncate
      BEFORE TRUNCATE ON #{name}
      FOR EACH STATEMENT EXECUTE FUNCTION audit_log_events_append_only()
    """)
  end

  defp half(%Date{month: 1}), do: "h1"
  defp half(%Date{month: 7}), do: "h2"

  defp create_indexes do
    [
      {"audit_events_time_idx", "(inserted_at DESC, id DESC)"},
      {"audit_events_type_time_idx", "(event_type, inserted_at DESC, id DESC)"},
      {"audit_events_project_time_idx",
       "(project_id, inserted_at DESC, id DESC) WHERE project_id IS NOT NULL"},
      {"audit_events_section_time_idx",
       "(section_id, inserted_at DESC, id DESC) WHERE section_id IS NOT NULL"},
      {"audit_events_user_time_idx",
       "(user_id, inserted_at DESC, id DESC) WHERE user_id IS NOT NULL"},
      {"audit_events_author_time_idx",
       "(author_id, inserted_at DESC, id DESC) WHERE author_id IS NOT NULL"},
      {"audit_events_affected_user_time_idx",
       "(affected_user_id, inserted_at DESC, id DESC) WHERE affected_user_id IS NOT NULL"},
      {"audit_events_affected_author_time_idx",
       "(affected_author_id, inserted_at DESC, id DESC) WHERE affected_author_id IS NOT NULL"},
      {"audit_events_parent_operation_idx",
       "(parent_operation_id) WHERE parent_operation_id IS NOT NULL"},
      {"audit_events_refs_idx", "USING GIN (refs jsonb_path_ops)"},
      {"audit_events_operation_idx", "(operation_id, event_key)"},
      {"audit_events_legacy_idx",
       "(legacy_source, legacy_id, inserted_at) WHERE legacy_source IS NOT NULL"},
      {"audit_events_search_idx", "USING GIN (search_vector)"}
    ]
    |> Enum.each(fn {name, definition} ->
      execute("CREATE INDEX #{name} ON audit_log_events_p #{definition}")
    end)
  end

  # Rows are append-only unless a documented procedure sets oli.audit_log_allow_mutation in its
  # own transaction. UPDATE, DELETE, and TRUNCATE are blocked; detaching or dropping a partition
  # is not a row change and is unaffected. A BEFORE trigger returning NULL on the TRUNCATE
  # statement path is ignored, so one function serves both triggers.
  defp create_append_only_guard do
    execute("""
    CREATE FUNCTION audit_log_events_append_only() RETURNS trigger
    LANGUAGE plpgsql AS $$
    BEGIN
      IF current_setting('oli.audit_log_allow_mutation', true) = 'on' THEN
        RETURN COALESCE(NEW, OLD);
      END IF;

      RAISE EXCEPTION 'audit_log_events is append-only';
    END;
    $$
    """)

    execute("""
    CREATE TRIGGER audit_log_events_append_only
      BEFORE UPDATE OR DELETE ON audit_log_events_p
      FOR EACH ROW EXECUTE FUNCTION audit_log_events_append_only()
    """)

    execute("""
    CREATE TRIGGER audit_log_events_no_truncate
      BEFORE TRUNCATE ON audit_log_events_p
      FOR EACH STATEMENT EXECUTE FUNCTION audit_log_events_append_only()
    """)
  end

  defp comment_columns do
    execute(
      "COMMENT ON TABLE audit_log_events_p IS 'Append-only audit events, partitioned by half-year on inserted_at'"
    )

    Enum.each(@columns, fn {column, comment} ->
      execute(
        "COMMENT ON COLUMN audit_log_events_p.#{column} IS '#{String.replace(comment, "'", "''")}'"
      )
    end)
  end
end
