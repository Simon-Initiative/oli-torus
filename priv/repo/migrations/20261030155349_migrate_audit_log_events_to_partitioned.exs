defmodule Oli.Repo.Migrations.MigrateAuditLogEventsToPartitioned do
  @moduledoc """
  Replaces the flat `audit_log_events` table with a table partitioned by half-year on
  `inserted_at` that enforces the versioned event envelope.

  This migration owns its SQL: it must not call `Oli.Auditing.EventCatalog`,
  `Oli.Auditing.LogEvent`, `Oli.Auditing.Partitions`, or any other application module, so later
  application changes cannot alter what it does.

  `up/0` copies every legacy row as `schema_version = 1` history, reconciles the copy against the
  legacy table, and only then drops it. `down/0` keeps the complete history in
  `audit_log_events_rollback_archive` and rebuilds the original table with the original event
  types; running `up/0` again restores the archive first. Each direction is one transaction, so a
  failure at any step leaves the previous table untouched.
  """

  use Ecto.Migration

  require Logger

  @future_intervals 4
  @chunk_size 1_000
  @archive "audit_log_events_rollback_archive"

  # The event types the legacy table could hold; only these are rebuilt on rollback.
  @legacy_event_types ~w(user_deleted author_deleted author_role_changed project_published
    section_created feature_flag_enabled feature_flag_disabled feature_flag_removed
    google_doc_imported feature_rollout_stage_changed feature_rollout_stage_deleted
    feature_rollout_exemption_upserted feature_rollout_exemption_deleted
    account_internal_flag_changed clickhouse_admin_operation_initiated resource_attempt_deleted)

  # Identity values legacy producers already stored in details; never joined from current records.
  @search_keys ~w(email name project_title section_title page_title feature_name author_name
    author_email actor_name)

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
    lock_audit_log_events()
    refuse_detached_partitions!()
    refuse_non_object_details!()
    archived? = archive_exists?()
    first_id = next_id(archived?)

    execute("CREATE SEQUENCE audit_events_id_seq AS bigint START WITH #{first_id}")

    create_parent()
    create_append_only_guard()
    Enum.each(partitions(archived?), &create_partition/1)
    create_indexes()
    comment_columns()
    # The steps below read and write the new table, so its DDL must have run.
    flush()

    restored = restore_archive(archived?)
    summary = copy_legacy_rows(first_id)
    # Autovacuum never analyzes a partitioned parent; the checks below and later reads need stats.
    repo().query!("ANALYZE audit_log_events_p")
    reconcile!()

    # Mutation privileges would let a role bypass the append-only guard, so they are not copied.
    copy_grants("audit_log_events", "audit_log_events_p", "TABLE", ~w(SELECT INSERT REFERENCES))
    copy_grants("audit_log_events_id_seq", "audit_events_id_seq", "SEQUENCE")

    execute("DROP TABLE audit_log_events")
    execute("ALTER TABLE audit_log_events_p RENAME TO audit_log_events")
    execute("DROP TABLE IF EXISTS #{@archive}")

    log_summary(restored, summary)
  end

  def down do
    lock_audit_log_events()
    refuse_detached_partitions!()

    # The archive keeps every event, including types the original table cannot hold, so a
    # roll-forward loses nothing.
    execute("""
    CREATE TABLE #{@archive} AS
      SELECT #{Enum.join(stored_columns(), ", ")} FROM audit_log_events
    """)

    create_legacy_table("audit_log_events_restore")
    restore_legacy_rows("audit_log_events_restore")
    flush()

    copy_grants("audit_log_events", "audit_log_events_restore", "TABLE")
    copy_grants("audit_events_id_seq", "audit_log_events_id_seq", "SEQUENCE")

    execute("DROP TABLE audit_log_events")
    execute("DROP FUNCTION audit_log_events_append_only()")
    execute("ALTER TABLE audit_log_events_restore RENAME TO audit_log_events")
  end

  defp lock_audit_log_events do
    execute("SET LOCAL lock_timeout = '5s'")
    execute("LOCK TABLE audit_log_events IN ACCESS EXCLUSIVE MODE")
    # execute/1 only queues commands; flush so the lock is held before the reads below.
    flush()
  end

  # A detached partition keeps its truncate trigger, which blocks dropping the guard function, and
  # its name, which blocks recreating that partition. Operators drop or reattach it first.
  defp refuse_detached_partitions! do
    %{rows: rows} =
      repo().query!("""
      SELECT relname FROM pg_class
      WHERE relname ~ '^audit_log_events_y[0-9]{4}h[12]$' AND relkind = 'r' AND NOT relispartition
      ORDER BY relname
      """)

    case List.flatten(rows) do
      [] -> :ok
      names -> raise "drop or reattach detached audit partitions first: #{Enum.join(names, ", ")}"
    end
  end

  # Only manual SQL can store non-object details; the error names row IDs, never values.
  defp refuse_non_object_details! do
    %{rows: rows} =
      repo().query!("""
      SELECT id FROM audit_log_events
      WHERE details IS NOT NULL AND jsonb_typeof(details) <> 'object'
      ORDER BY id
      """)

    case List.flatten(rows) do
      [] ->
        :ok

      ids ->
        raise "#{length(ids)} audit_log_events rows have details that are not a JSON object; " <>
                "fix them before migrating (ids: #{ids |> Enum.take(20) |> Enum.join(", ")})"
    end
  end

  defp archive_exists? do
    %{rows: [[exists?]]} = repo().query!("SELECT to_regclass($1) IS NOT NULL", [@archive])
    exists?
  end

  defp stored_columns, do: Keyword.keys(@columns) -- [:search_vector]

  # Every new ID is above every legacy and archived ID, so a rollback can restore legacy IDs
  # and a roll-forward can restore archived IDs without collisions.
  defp next_id(archived?) do
    archive_max =
      case archived? do
        true -> "(SELECT max(id) FROM #{@archive})"
        false -> "0"
      end

    %{rows: [[max_id]]} =
      repo().query!("""
      SELECT GREATEST(
        (SELECT COALESCE(max(id), 0) FROM audit_log_events),
        (SELECT last_value FROM audit_log_events_id_seq),
        COALESCE(#{archive_max}, 0))
      """)

    max_id + 1
  end

  defp restore_archive(false), do: 0

  defp restore_archive(true) do
    columns = Enum.join(stored_columns(), ", ")

    %{num_rows: restored} =
      repo().query!("""
      INSERT INTO audit_log_events_p (#{columns}) SELECT #{columns} FROM #{@archive} ORDER BY id
      """)

    restored
  end

  # A legacy row is already present when the archive held it: as a migrated row under its legacy
  # ID, or as an application event that the rollback rebuilt under its own ID. Matching on
  # inserted_at too lets PostgreSQL skip the other partitions, and a row edited after the rollback
  # is copied again, which reconciliation then reports as a duplicate.
  defp represented(legacy) do
    """
    (EXISTS (SELECT 1 FROM audit_log_events_p p
              WHERE p.schema_version = 1 AND p.legacy_source = 'audit_log_events'
                AND p.legacy_id = #{legacy}.id AND p.inserted_at = #{legacy}.inserted_at)
     OR #{rebuilt_event(legacy)})
    """
  end

  defp rebuilt_event(legacy) do
    """
    EXISTS (SELECT 1 FROM audit_log_events_p p
             WHERE p.schema_version = 2 AND p.id = #{legacy}.id
               AND p.inserted_at = #{legacy}.inserted_at AND p.event_type = #{legacy}.event_type)
    """
  end

  # Reads and transforms rows here, in source ID order, so new IDs keep the original order.
  # Chunks only respect the parameter limit; they share the migration transaction.
  defp copy_legacy_rows(first_id) do
    %{rows: rows} =
      repo().query!("""
      SELECT id, inserted_at, event_type, user_id, author_id, project_id, section_id,
             resource_id, details
      FROM audit_log_events l
      WHERE NOT #{represented("l")}
      ORDER BY id
      """)

    projected = rows |> Enum.with_index(first_id) |> Enum.map(&project_row/1)

    projected
    |> Enum.map(fn {row, _redacted} -> row end)
    |> Enum.chunk_every(@chunk_size)
    |> Enum.each(&repo().insert_all("audit_log_events_p", &1))

    case length(projected) do
      0 -> :ok
      count -> repo().query!("SELECT setval('audit_events_id_seq', $1)", [first_id + count - 1])
    end

    # Only the counts outlive this function, so the projected rows are released before reconcile.
    %{
      copied: length(projected),
      by_type: projected |> Enum.map(fn {row, _} -> row.event_type end) |> Enum.frequencies(),
      redacted: projected |> Enum.flat_map(fn {_, words} -> words end) |> Enum.frequencies(),
      ambiguous: Enum.count(projected, fn {row, _} -> row.user_id && row.author_id end)
    }
  end

  defp project_row(
         {[
            legacy_id,
            inserted_at,
            event_type,
            user_id,
            author_id,
            project_id,
            section_id,
            resource_id,
            details
          ], id}
       ) do
    {projected_details, redacted} = project_details(details, resource_id)

    {entity_type, entity_id, affected_user_id, affected_author_id} =
      entity(event_type, details || %{}, resource_id, project_id, section_id)

    row = %{
      id: id,
      inserted_at: inserted_at,
      schema_version: 1,
      event_type: event_type,
      outcome: outcome(event_type),
      actor_type: actor_type(user_id, author_id),
      user_id: user_id,
      author_id: author_id,
      entity_type: entity_type,
      entity_id: entity_id,
      affected_user_id: affected_user_id,
      affected_author_id: affected_author_id,
      project_id: project_id,
      section_id: section_id,
      details: projected_details,
      legacy_source: "audit_log_events",
      legacy_id: legacy_id,
      search_text: search_text(projected_details)
    }

    {row, redacted}
  end

  # Legacy rows used resource_id for IDs that are not course resources, so the value moves into
  # details, where a rollback can read it back.
  defp project_details(details, resource_id) do
    {sanitized, redacted} = sanitize(details || %{})

    case resource_id do
      nil ->
        {sanitized, redacted}

      id ->
        reference = %{"id" => id, "type" => sanitized["resource_type"]}
        {Map.put(sanitized, "legacy_resource_ref", reference), redacted}
    end
  end

  # Replaces the value of every secret-looking key, at any depth, with a marker. Returns the
  # sanitized value and the matched pattern words; key names come from data and are not logged.
  defp sanitize(map) when is_map(map) do
    Enum.reduce(map, {%{}, []}, fn {key, value}, {acc, redacted} ->
      case Regex.run(
             ~r/password|secret|token|credential|api_key|private_key|authorization|cookie/i,
             key
           ) do
        [word] ->
          {Map.put(acc, key, %{"redacted" => true}), [String.downcase(word) | redacted]}

        nil ->
          {value, nested} = sanitize(value)
          {Map.put(acc, key, value), nested ++ redacted}
      end
    end)
  end

  defp sanitize(list) when is_list(list) do
    {values, redacted} = Enum.map(list, &sanitize/1) |> Enum.unzip()
    {values, List.flatten(redacted)}
  end

  defp sanitize(value), do: {value, []}

  defp entity(_type, %{"resource_type" => "Elixir.Oli.Accounts.User"}, id, _project, _section)
       when is_integer(id),
       do: {"user", Integer.to_string(id), id, nil}

  defp entity(_type, %{"resource_type" => "Elixir.Oli.Accounts.Author"}, id, _project, _section)
       when is_integer(id),
       do: {"author", Integer.to_string(id), nil, id}

  defp entity("section_created", _details, _id, _project, section_id) when is_integer(section_id),
    do: {"section", Integer.to_string(section_id), nil, nil}

  defp entity("project_published", _details, _id, project_id, _section)
       when is_integer(project_id),
       do: {"project", Integer.to_string(project_id), nil, nil}

  defp entity(_type, _details, _id, _project, _section), do: {nil, nil, nil, nil}

  defp outcome("clickhouse_admin_operation_initiated"), do: "initiated"
  defp outcome(_type), do: nil

  # Both IDs are not producible by the application, only by manual SQL; both are kept and the
  # actor stays unknown.
  defp actor_type(user_id, nil) when is_integer(user_id), do: "user"
  defp actor_type(nil, author_id) when is_integer(author_id), do: "author"
  defp actor_type(_user_id, _author_id), do: "unknown"

  defp search_text(details) do
    @search_keys
    |> Enum.map(&details[&1])
    |> Enum.filter(&(is_binary(&1) and &1 != ""))
    |> Enum.join(" ")
  end

  # Any mismatch raises, which rolls back the whole migration and leaves the legacy table intact.
  defp reconcile! do
    migrated = "p.schema_version = 1 AND p.legacy_source = 'audit_log_events'"
    legacy_types = Enum.map_join(@legacy_event_types, ", ", &"'#{&1}'")

    counts = [
      legacy_rows_missing:
        "SELECT count(*) FROM audit_log_events l WHERE NOT #{represented("l")}",
      migrated_rows_without_legacy_row: """
      SELECT count(*) FROM audit_log_events_p p
      WHERE #{migrated} AND NOT EXISTS (SELECT 1 FROM audit_log_events l WHERE l.id = p.legacy_id)
      """,
      archived_events_without_legacy_row: """
      SELECT count(*) FROM audit_log_events_p p
      WHERE p.schema_version = 2 AND p.event_type IN (#{legacy_types})
        AND NOT EXISTS (SELECT 1 FROM audit_log_events l
                        WHERE l.id = p.id AND l.inserted_at = p.inserted_at
                          AND l.event_type = p.event_type)
      """,
      duplicate_legacy_ids:
        "SELECT count(*) - count(DISTINCT legacy_id) FROM audit_log_events_p p WHERE #{migrated}",
      out_of_order_ids: """
      SELECT count(*) FROM (
        SELECT id, lag(id) OVER (ORDER BY legacy_id) AS previous_id
        FROM audit_log_events_p p WHERE #{migrated}) ordered
      WHERE id < previous_id
      """
    ]

    mismatches =
      counts
      |> Enum.map(fn {check, sql} ->
        %{rows: [[count]]} = repo().query!(sql)
        {check, count}
      end)
      |> Enum.concat(
        checksum_mismatch: checksum_mismatch(migrated),
        details_mismatch: details_mismatches(migrated)
      )
      |> Enum.reject(fn {_check, count} -> count == 0 end)

    case mismatches do
      [] -> :ok
      _ -> raise "audit_log_events reconciliation failed: #{inspect(mismatches)}"
    end
  end

  defp checksum_mismatch(migrated) do
    fields = fn id, alias ->
      "concat_ws('|', #{id}, #{alias}.inserted_at, #{alias}.event_type, " <>
        Enum.map_join(
          ~w(user_id author_id project_id section_id),
          ", ",
          &"COALESCE(#{alias}.#{&1}::text, '')"
        ) <> ")"
    end

    %{rows: [[legacy, migrated_checksum]]} =
      repo().query!("""
      SELECT
        (SELECT md5(string_agg(#{fields.("l.id", "l")}, ',' ORDER BY l.id))
         FROM audit_log_events l
         WHERE NOT #{rebuilt_event("l")}),
        (SELECT md5(string_agg(#{fields.("p.legacy_id", "p")}, ',' ORDER BY p.legacy_id))
         FROM audit_log_events_p p WHERE #{migrated})
      """)

    case legacy == migrated_checksum do
      true -> 0
      false -> 1
    end
  end

  # Recomputes the sanitized details from each legacy row and compares them with what is stored.
  defp details_mismatches(migrated) do
    %{rows: stored} =
      repo().query!("SELECT p.legacy_id, p.details FROM audit_log_events_p p WHERE #{migrated}")

    stored = Map.new(stored, fn [legacy_id, details] -> {legacy_id, details} end)

    %{rows: legacy} =
      repo().query!("""
      SELECT l.id, l.resource_id, l.details FROM audit_log_events l
      WHERE NOT #{rebuilt_event("l")}
      """)

    Enum.count(legacy, fn [id, resource_id, details] ->
      {expected, _redacted} = project_details(details, resource_id)
      Map.get(stored, id) != expected
    end)
  end

  # Grants absent from the target, such as a read-only reporting role, are copied from the source,
  # limited to `privileges` when given. Column grants are not copied.
  defp copy_grants(source, target, kind, privileges \\ :all) do
    missing =
      Enum.filter(grants(source) -- grants(target), fn [privilege | _] ->
        privileges == :all or privilege in privileges
      end)

    Enum.each(missing, fn [privilege, grantee, grantable?] ->
      option =
        case grantable? do
          true -> " WITH GRANT OPTION"
          false -> ""
        end

      repo().query!("GRANT #{privilege} ON #{kind} #{target} TO #{grantee}#{option}")
    end)
  end

  defp grants(relation) do
    %{rows: rows} =
      repo().query!(
        """
        SELECT a.privilege_type,
               CASE WHEN a.grantee = 0 THEN 'PUBLIC'
                    ELSE quote_ident(pg_get_userbyid(a.grantee)) END,
               a.is_grantable
        FROM pg_class c, aclexplode(c.relacl) a
        WHERE c.oid = $1::text::regclass
        """,
        [relation]
      )

    rows
  end

  # Counts and pattern words only; never values or key names.
  defp log_summary(restored, summary) do
    Logger.info(
      "audit_log_events migrated: restored_from_archive=#{restored} copied=#{summary.copied} " <>
        "by_type=#{inspect(summary.by_type)} redacted=#{inspect(summary.redacted)} " <>
        "ambiguous_actors=#{summary.ambiguous}"
    )
  end

  # The original table definition and index names, under a temporary name until the swap.
  defp create_legacy_table(name) do
    execute("CREATE SEQUENCE audit_log_events_id_seq")

    execute("""
    CREATE TABLE #{name} (
      id bigint NOT NULL DEFAULT nextval('audit_log_events_id_seq'),
      user_id integer,
      author_id integer,
      event_type varchar(255) NOT NULL,
      section_id integer,
      project_id integer,
      resource_id integer,
      details jsonb DEFAULT '{}'::jsonb,
      inserted_at timestamptz NOT NULL,
      CONSTRAINT audit_log_events_pkey PRIMARY KEY (id)
    )
    """)

    execute("ALTER SEQUENCE audit_log_events_id_seq OWNED BY #{name}.id")

    for column <- ~w(user_id author_id section_id project_id event_type inserted_at) do
      execute("CREATE INDEX audit_log_events_#{column}_index ON #{name} (#{column})")
    end
  end

  # Every migrated row returns under its legacy ID with resource_id restored, so a roll-forward
  # finds all of them; application events of the original types return under their own ID in the
  # legacy shape. Details stay sanitized, and NULL details come back as the column default `{}`.
  defp restore_legacy_rows(name) do
    legacy_types = Enum.map_join(@legacy_event_types, ", ", &"'#{&1}'")

    execute("""
    INSERT INTO #{name}
      (id, user_id, author_id, event_type, section_id, project_id, resource_id, details,
       inserted_at)
    SELECT legacy_id, user_id, author_id, event_type, section_id, project_id,
           (details #>> '{legacy_resource_ref,id}')::integer, details - 'legacy_resource_ref',
           inserted_at
    FROM #{@archive}
    WHERE schema_version = 1 AND legacy_source = 'audit_log_events'
    UNION ALL
    SELECT id, user_id, author_id, event_type, section_id, project_id,
           CASE WHEN entity_type IN ('user', 'author') THEN entity_id::integer END,
           CASE entity_type
             WHEN 'user' THEN details || '{"resource_type": "Elixir.Oli.Accounts.User"}'
             WHEN 'author' THEN details || '{"resource_type": "Elixir.Oli.Accounts.Author"}'
             ELSE details
           END,
           inserted_at
    FROM #{@archive}
    WHERE schema_version = 2 AND event_type IN (#{legacy_types})
    """)

    execute("""
    SELECT setval('audit_log_events_id_seq', GREATEST(max_id, 1), max_id > 0)
    FROM (SELECT COALESCE(max(GREATEST(id, legacy_id)), 0) AS max_id FROM #{@archive}) archived
    """)
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

  # From the half-year holding the oldest row of audit_log_events, settings_changes, or the
  # rollback archive (the current one when all are empty) through the current half-year plus four
  # future ones.
  defp partitions(archived?) do
    archive_oldest =
      case archived? do
        true -> "(SELECT min(inserted_at) FROM #{@archive})"
        false -> "NULL"
      end

    %{rows: [[oldest]]} =
      repo().query!("""
      SELECT least(
        (SELECT min(inserted_at) FROM audit_log_events),
        (SELECT min(inserted_at) FROM settings_changes),
        #{archive_oldest})
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
