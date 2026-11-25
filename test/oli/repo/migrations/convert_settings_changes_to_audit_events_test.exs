defmodule Oli.Repo.Migrations.ConvertSettingsChangesToAuditEventsTest do
  # Runs the migration's down/0 and up/0 inside the test's sandbox transaction, so the test
  # database is left as it was.
  use Oli.DataCase, async: false

  import Oli.Factory

  @version 20_261_119_193_918
  @migration Oli.Repo.Migrations.ConvertSettingsChangesToAuditEvents

  # `mix test` migrates the test database in this VM first, which already loads the migration.
  unless Code.ensure_loaded?(@migration) do
    Code.require_file(
      "priv/repo/migrations/20261119193918_convert_settings_changes_to_audit_events.exs"
    )
  end

  setup do
    migrate(:down)
    section = insert(:section)
    resource = insert(:resource)
    %{section: section, resource: resource}
  end

  test "up/0 converts every history row and drops the table; down/0 restores it", %{
    section: section,
    resource: resource
  } do
    rows = [
      history(1, section, resource, "author", 11, "max_attempts", "1", "3"),
      history(2, section, resource, "instructor", 22, "late_submit", "allow", "disallow"),
      history(3, section, resource, "instructor", 33, "password", "old secret", "new secret"),
      history(4, section, resource, "instructor", 44, "end_date", nil, "2025-01-02T00:00:00Z"),
      history(5, section, resource, nil, 55, "time_limit", "0", "45")
    ]

    insert_history(rows)
    migrate(:up)

    refute table_exists?("settings_changes")

    converted =
      Repo.query!("""
      SELECT legacy_id, inserted_at, actor_type, user_id, author_id, entity_type, entity_id,
             section_id, resource_id, changes, details
      FROM audit_log_events
      WHERE schema_version = 1 AND legacy_source = 'settings_changes'
      ORDER BY legacy_id
      """).rows

    assert length(converted) == 5

    [author_row, instructor_row, password_row, null_before_row, unknown_row] = converted

    # Actor type, original time, scope, and the setting as one change record
    expected_time = utc(1)

    assert [
             1,
             ^expected_time,
             "author",
             nil,
             11,
             "resource",
             entity_id,
             section_id,
             resource_id,
             %{"max_attempts" => max_attempts},
             %{}
           ] = author_row

    assert {entity_id, section_id, resource_id} ==
             {to_string(resource.id), section.id, resource.id}

    assert max_attempts == %{"operation" => "set", "before" => "1", "after" => "3"}

    assert [2, _, "user", 22, nil | _] = instructor_row

    # Passwords keep only the redaction marker
    assert Enum.at(password_row, 9) == %{
             "password" => %{"operation" => "set", "redacted" => true, "changed" => true}
           }

    refute inspect(converted) =~ "secret"

    # A null value stays an explicit null
    assert Enum.at(null_before_row, 9) == %{
             "end_date" => %{
               "operation" => "set",
               "before" => nil,
               "after" => "2025-01-02T00:00:00Z"
             }
           }

    # An unknown user type keeps the account for the rollback
    assert [5, _, "unknown", nil, nil | _] = unknown_row

    assert List.last(unknown_row) == %{"legacy_user_id" => 55, "legacy_user_type" => nil}

    migrate(:down)

    restored =
      Repo.query!("""
      SELECT id, resource_id, section_id, user_id, user_type, key, old_value, new_value,
             inserted_at
      FROM settings_changes ORDER BY id
      """).rows

    assert restored == [
             [
               1,
               resource.id,
               section.id,
               11,
               "author",
               "max_attempts",
               "1",
               "3",
               utc(1)
             ],
             [
               2,
               resource.id,
               section.id,
               22,
               "instructor",
               "late_submit",
               "allow",
               "disallow",
               utc(2)
             ],
             [
               3,
               resource.id,
               section.id,
               33,
               "instructor",
               "password",
               "[redacted]",
               "[redacted]",
               utc(3)
             ],
             [
               4,
               resource.id,
               section.id,
               44,
               "instructor",
               "end_date",
               nil,
               "2025-01-02T00:00:00Z",
               utc(4)
             ],
             [
               5,
               resource.id,
               section.id,
               55,
               nil,
               "time_limit",
               "0",
               "45",
               utc(5)
             ]
           ]

    assert converted_count() == 0

    # The sequence continues after the restored IDs
    %{rows: [[next_id]]} =
      Repo.query!("""
      INSERT INTO settings_changes (key, inserted_at, updated_at)
      VALUES ('max_attempts', now(), now()) RETURNING id
      """)

    assert next_id == 6
  end

  test "up/0 restarts after a partial conversion without duplicating rows", %{
    section: section,
    resource: resource
  } do
    insert_history([
      history(1, section, resource, "author", 11, "max_attempts", "1", "3"),
      history(2, section, resource, "instructor", 22, "time_limit", "0", "30")
    ])

    # A row converted by an earlier, interrupted run
    Repo.query!(
      """
      INSERT INTO audit_log_events (inserted_at, schema_version, event_type, actor_type,
        author_id, legacy_source, legacy_id)
      VALUES ($1, 1, 'assessment_setting_changed', 'author', 11, 'settings_changes', 1)
      """,
      [DateTime.from_naive!(at(1), "Etc/UTC")]
    )

    migrate(:up)

    assert converted_count() == 2
  end

  defp history(id, section, resource, user_type, user_id, key, old_value, new_value) do
    [
      id,
      resource.id,
      section.id,
      user_id,
      user_type,
      key,
      new_value,
      old_value,
      DateTime.from_naive!(at(id), "Etc/UTC")
    ]
  end

  # As PostgreSQL returns it: UTC with microsecond precision.
  defp utc(seconds),
    do: seconds |> at() |> DateTime.from_naive!("Etc/UTC") |> DateTime.add(0, :microsecond)

  # The test database has partitions from the current half-year on, so history times fall in it.
  defp at(seconds) do
    today = Date.utc_today()
    month = if today.month < 7, do: 1, else: 7

    today.year
    |> Date.new!(month, 2)
    |> NaiveDateTime.new!(~T[10:00:00])
    |> NaiveDateTime.add(seconds)
  end

  defp insert_history(rows) do
    Enum.each(rows, fn row ->
      Repo.query!(
        """
        INSERT INTO settings_changes (id, resource_id, section_id, user_id, user_type, key,
          new_value, old_value, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $9)
        """,
        row
      )
    end)
  end

  defp converted_count do
    %{rows: [[count]]} =
      Repo.query!("""
      SELECT count(*) FROM audit_log_events
      WHERE schema_version = 1 AND legacy_source = 'settings_changes'
      """)

    count
  end

  defp table_exists?(name) do
    %{rows: [[exists]]} = Repo.query!("SELECT to_regclass($1) IS NOT NULL", [name])
    exists
  end

  defp migrate(direction) do
    Ecto.Migrator.run(Repo, [{@version, @migration}], direction,
      all: true,
      log: false,
      migration_lock: false
    )
  end
end
