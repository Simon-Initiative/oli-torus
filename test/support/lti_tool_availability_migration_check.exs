# Run with MIX_ENV=test mix run --no-start test/support/lti_tool_availability_migration_check.exs
# Uses a new disposable database and refuses to reuse an existing one.
defmodule LtiToolAvailabilityMigrationRepo do
  use Ecto.Repo, otp_app: :oli, adapter: Ecto.Adapters.Postgres
end

unless Mix.env() == :test, do: raise("Migration rehearsal requires MIX_ENV=test")
{:ok, _} = Application.ensure_all_started(:ecto_sql)

config =
  Oli.Repo.config()
  |> Keyword.put(:database, "oli_lti_tool_availability_migration_check")
  |> Keyword.put(:pool, DBConnection.ConnectionPool)
  |> Keyword.put(:pool_size, 2)
  |> Keyword.delete(:url)

case Ecto.Adapters.Postgres.storage_up(config) do
  :ok -> :ok
  other -> raise("Refusing to reuse or delete rehearsal database: #{inspect(other)}")
end

try do
  {:ok, _pid} = LtiToolAvailabilityMigrationRepo.start_link(config)
  repo = LtiToolAvailabilityMigrationRepo
  sql = fn statement -> Ecto.Adapters.SQL.query!(repo, statement, []) end

  sql.("CREATE TABLE activity_registrations (id bigserial PRIMARY KEY)")
  sql.("CREATE TABLE lti_1p3_platform_instances (id bigserial PRIMARY KEY)")
  sql.("CREATE TABLE projects (id bigserial PRIMARY KEY)")

  sql.("""
  CREATE TABLE lti_external_tool_activity_deployments (
    deployment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_registration_id bigint NOT NULL REFERENCES activity_registrations(id),
    platform_instance_id bigint NOT NULL REFERENCES lti_1p3_platform_instances(id),
    status varchar NOT NULL DEFAULT 'enabled',
    deep_linking_enabled boolean NOT NULL DEFAULT false,
    inserted_at timestamp NOT NULL DEFAULT now(),
    updated_at timestamp NOT NULL DEFAULT now()
  )
  """)

  sql.("""
  CREATE TABLE activity_registration_projects (
    activity_registration_id bigint NOT NULL REFERENCES activity_registrations(id),
    project_id bigint NOT NULL REFERENCES projects(id),
    status varchar NOT NULL DEFAULT 'enabled',
    PRIMARY KEY (activity_registration_id, project_id)
  )
  """)

  sql.("INSERT INTO activity_registrations SELECT FROM generate_series(1, 4)")
  sql.("INSERT INTO lti_1p3_platform_instances SELECT FROM generate_series(1, 4)")
  sql.("INSERT INTO projects SELECT FROM generate_series(1, 2)")

  sql.("""
  INSERT INTO lti_external_tool_activity_deployments
    (activity_registration_id, platform_instance_id, status, deep_linking_enabled)
  VALUES (1, 1, 'enabled', true), (2, 2, 'disabled', false), (3, 3, 'deleted', true)
  """)

  sql.("""
  INSERT INTO activity_registration_projects (activity_registration_id, project_id, status)
  VALUES (1, 1, 'enabled'), (2, 1, 'disabled'), (1, 2, 'enabled')
  """)

  existing =
    "SELECT activity_registration_id, status, deep_linking_enabled FROM lti_external_tool_activity_deployments ORDER BY activity_registration_id"

  associations =
    "SELECT activity_registration_id, project_id, status FROM activity_registration_projects ORDER BY 1, 2"

  %{rows: existing_before} = sql.(existing)
  %{rows: associations_before} = sql.(associations)

  Code.require_file(
    "priv/repo/migrations/20261102234345_add_availability_and_project_grants_to_lti_external_tools.exs"
  )

  migration = Oli.Repo.Migrations.AddAvailabilityAndProjectGrantsToLtiExternalTools
  version = 20_261_102_234_345
  :ok = Ecto.Migrator.up(repo, version, migration, log: false)

  %{rows: [["public"], ["public"], ["public"]]} =
    sql.(
      "SELECT availability FROM lti_external_tool_activity_deployments ORDER BY activity_registration_id"
    )

  %{rows: ^existing_before} = sql.(existing)
  %{rows: ^associations_before} = sql.(associations)

  %{rows: [["private"]]} =
    sql.("""
    INSERT INTO lti_external_tool_activity_deployments (activity_registration_id, platform_instance_id)
    VALUES (4, 4) RETURNING availability
    """)

  sql.("""
  INSERT INTO lti_external_tool_project_grants (deployment_id, project_id, inserted_at, updated_at)
  SELECT deployment_id, 1, now(), now() FROM lti_external_tool_activity_deployments
  WHERE activity_registration_id = 1
  """)

  {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
    Ecto.Adapters.SQL.query(
      repo,
      """
      INSERT INTO lti_external_tool_project_grants (deployment_id, project_id, inserted_at, updated_at)
      SELECT deployment_id, 1, now(), now() FROM lti_external_tool_activity_deployments
      WHERE activity_registration_id = 1
      """,
      []
    )

  %{rows: existing_before_down} = sql.(existing)
  :ok = Ecto.Migrator.down(repo, version, migration, log: false)
  %{rows: ^existing_before_down} = sql.(existing)

  %{rows: [[0]]} =
    sql.("""
    SELECT count(*) FROM information_schema.columns
    WHERE table_name = 'lti_external_tool_activity_deployments' AND column_name = 'availability'
    """)

  %{rows: [[nil]]} = sql.("SELECT to_regclass('lti_external_tool_project_grants')")
  %{rows: ^associations_before} = sql.(associations)

  :ok = Ecto.Migrator.up(repo, version, migration, log: false)

  %{rows: [["public"], ["public"], ["public"], ["public"]]} =
    sql.(
      "SELECT availability FROM lti_external_tool_activity_deployments ORDER BY activity_registration_id"
    )

  IO.puts(
    "Availability migration up/down/up passed: existing tools Public, new tools Private, " <>
      "status, deep linking and associations unchanged, grants unique, rollback clean."
  )
after
  case Process.whereis(LtiToolAvailabilityMigrationRepo) do
    nil -> :ok
    pid -> Supervisor.stop(pid)
  end

  :ok = Ecto.Adapters.Postgres.storage_down(config)
end
