defmodule Oli.Repo.Migrations.ConvertSettingsChangesToAuditEvents do
  @moduledoc """
  Converts the assessment settings history in `settings_changes` into version 1
  `assessment_setting_changed` rows of `audit_log_events`, and drops `settings_changes`.

  This migration owns its SQL: it must not call `Oli.Auditing`, `Oli.Delivery.Settings`, or any
  other application module, so later application changes cannot alter what it does.

  `up/0` inserts one row per history row with a new central ID, the original time, the actor
  (`user_type = 'author'` as an author, `'instructor'` as a user; any other type is unknown and
  keeps the original account ID and type in `details` for the rollback), the
  section and resource scope, and the setting as one change record whose `before` and `after`
  are the stored text values. A `password` change keeps only the redaction marker, never its
  values. `legacy_source = 'settings_changes'` and `legacy_id` record the provenance, and an
  anti-join on them makes the insert restartable. The table is dropped only when every history
  row has its converted row.

  `down/0` recreates `settings_changes` from the converted rows, with their original IDs and the
  text `[redacted]` where a password was (the values are not recoverable), and deletes the
  converted rows. Each direction is one transaction.
  """

  use Ecto.Migration

  @redacted_record ~s({"operation": "set", "redacted": true, "changed": true})
  @redacted_text "[redacted]"

  @resource_id_comment_v1 "Course resource scope (no foreign key); NULL on v1 rows"
  @resource_id_comment "Course resource scope (no foreign key); on v1 rows only for converted settings_changes history"

  def up do
    execute("LOCK TABLE settings_changes IN SHARE MODE")

    execute("""
    INSERT INTO audit_log_events (
      inserted_at, schema_version, event_type, actor_type, user_id, author_id,
      entity_type, entity_id, section_id, resource_id, changes, details, legacy_source,
      legacy_id
    )
    SELECT
      sc.inserted_at,
      1,
      'assessment_setting_changed',
      CASE
        WHEN sc.user_id IS NULL THEN 'unknown'
        WHEN sc.user_type = 'author' THEN 'author'
        WHEN sc.user_type = 'instructor' THEN 'user'
        ELSE 'unknown'
      END,
      CASE WHEN sc.user_type = 'instructor' THEN sc.user_id END,
      CASE WHEN sc.user_type = 'author' THEN sc.user_id END,
      CASE WHEN sc.resource_id IS NOT NULL THEN 'resource' END,
      sc.resource_id::text,
      sc.section_id,
      sc.resource_id,
      CASE
        WHEN sc.key IS NULL THEN '{}'::jsonb
        WHEN sc.key = 'password' THEN jsonb_build_object(sc.key, '#{@redacted_record}'::jsonb)
        ELSE jsonb_build_object(
          sc.key,
          jsonb_build_object('operation', 'set', 'before', sc.old_value, 'after', sc.new_value)
        )
      END,
      CASE
        WHEN sc.user_id IS NOT NULL AND sc.user_type IS DISTINCT FROM 'author'
             AND sc.user_type IS DISTINCT FROM 'instructor'
          THEN jsonb_build_object('legacy_user_id', sc.user_id, 'legacy_user_type', sc.user_type)
        ELSE '{}'::jsonb
      END,
      'settings_changes',
      sc.id
    FROM settings_changes sc
    WHERE NOT EXISTS (
      SELECT 1 FROM audit_log_events e
      WHERE e.legacy_source = 'settings_changes' AND e.legacy_id = sc.id
        AND e.inserted_at = sc.inserted_at
    )
    ORDER BY sc.id
    """)

    execute(&reconcile!/0)
    execute("COMMENT ON COLUMN audit_log_events.resource_id IS '#{@resource_id_comment}'")
    execute("DROP TABLE settings_changes")
  end

  def down do
    execute("""
    CREATE TABLE settings_changes (
      id bigserial PRIMARY KEY,
      resource_id bigint REFERENCES resources(id),
      section_id bigint REFERENCES sections(id),
      user_id integer,
      user_type varchar(255),
      key varchar(255),
      new_value varchar(255),
      old_value varchar(255),
      inserted_at timestamptz NOT NULL,
      updated_at timestamptz NOT NULL
    )
    """)

    execute("""
    INSERT INTO settings_changes (
      id, resource_id, section_id, user_id, user_type, key, new_value, old_value,
      inserted_at, updated_at
    )
    SELECT
      e.legacy_id,
      e.resource_id,
      e.section_id,
      COALESCE(e.user_id, e.author_id, (e.details->>'legacy_user_id')::integer),
      CASE e.actor_type
        WHEN 'author' THEN 'author'
        WHEN 'user' THEN 'instructor'
        ELSE e.details->>'legacy_user_type'
      END,
      c.key,
      CASE WHEN c.value ? 'redacted' THEN '#{@redacted_text}' ELSE c.value->>'after' END,
      CASE WHEN c.value ? 'redacted' THEN '#{@redacted_text}' ELSE c.value->>'before' END,
      e.inserted_at,
      e.inserted_at
    FROM audit_log_events e
    LEFT JOIN LATERAL jsonb_each(e.changes) c ON true
    WHERE e.schema_version = 1 AND e.legacy_source = 'settings_changes'
    ORDER BY e.legacy_id
    """)

    execute("""
    SELECT setval(pg_get_serial_sequence('settings_changes', 'id'),
                  COALESCE((SELECT max(id) FROM settings_changes), 1),
                  (SELECT count(*) > 0 FROM settings_changes))
    """)

    execute("SET LOCAL oli.audit_log_allow_mutation = 'on'")

    execute("""
    DELETE FROM audit_log_events
    WHERE schema_version = 1 AND legacy_source = 'settings_changes'
    """)

    execute("COMMENT ON COLUMN audit_log_events.resource_id IS '#{@resource_id_comment_v1}'")
  end

  # Every history row must have exactly one converted row before the table is dropped.
  defp reconcile! do
    %{rows: [[source, converted, duplicated]]} =
      repo().query!("""
      SELECT
        (SELECT count(*) FROM settings_changes),
        (SELECT count(DISTINCT legacy_id) FROM audit_log_events
          WHERE schema_version = 1 AND legacy_source = 'settings_changes'),
        (SELECT count(*) - count(DISTINCT legacy_id) FROM audit_log_events
          WHERE schema_version = 1 AND legacy_source = 'settings_changes')
      """)

    case {source == converted, duplicated} do
      {true, 0} ->
        :ok

      _mismatch ->
        raise "settings_changes conversion does not reconcile: #{source} history rows, " <>
                "#{converted} converted, #{duplicated} duplicated; nothing was dropped"
    end
  end
end
