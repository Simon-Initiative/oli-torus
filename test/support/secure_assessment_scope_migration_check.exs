# Run with MIX_ENV=test mix run --no-start test/support/secure_assessment_scope_migration_check.exs
# Uses a new disposable database and refuses to reuse an existing one.
defmodule SecureAssessmentScopeMigrationRepo do
  use Ecto.Repo, otp_app: :oli, adapter: Ecto.Adapters.Postgres
end

unless Mix.env() == :test, do: raise("Migration rehearsal requires MIX_ENV=test")
{:ok, _} = Application.ensure_all_started(:ecto_sql)

config =
  Oli.Repo.config()
  |> Keyword.put(:database, "oli_secure_assessment_scope_migration_check")
  |> Keyword.put(:pool, DBConnection.ConnectionPool)
  |> Keyword.put(:pool_size, 2)
  |> Keyword.delete(:url)

case Ecto.Adapters.Postgres.storage_up(config) do
  :ok -> :ok
  other -> raise("Refusing to reuse or delete rehearsal database: #{inspect(other)}")
end

try do
  {:ok, _pid} = SecureAssessmentScopeMigrationRepo.start_link(config)
  repo = SecureAssessmentScopeMigrationRepo
  sql = fn statement -> Ecto.Adapters.SQL.query!(repo, statement, []) end
  sql.("CREATE TABLE sections (id bigserial PRIMARY KEY)")
  sql.("CREATE TABLE resources (id bigserial PRIMARY KEY)")
  sql.("CREATE TABLE users_tokens (id bigserial PRIMARY KEY, context text NOT NULL)")
  sql.("INSERT INTO sections DEFAULT VALUES")
  sql.("INSERT INTO resources DEFAULT VALUES")
  sql.("INSERT INTO users_tokens (context) VALUES ('session')")

  Code.require_file(
    "priv/repo/migrations/20260922153129_add_secure_assessment_scope_to_users_tokens.exs"
  )

  migration = Oli.Repo.Migrations.AddSecureAssessmentScopeToUsersTokens
  version = 20_260_922_153_129
  :ok = Ecto.Migrator.up(repo, version, migration, log: false)

  for statement <- [
        "INSERT INTO users_tokens (context, secure_section_id) VALUES ('session', 1)",
        "INSERT INTO users_tokens (context, secure_resource_id) VALUES ('session', 1)",
        "INSERT INTO users_tokens (context, secure_section_id, secure_resource_id) VALUES ('reset', 1, 1)"
      ] do
    {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} =
      Ecto.Adapters.SQL.query(repo, statement, [])
  end

  sql.(
    "INSERT INTO users_tokens (context, secure_section_id, secure_resource_id) VALUES ('session', 1, 1)"
  )

  :ok = Ecto.Migrator.down(repo, version, migration, log: false)
  %{rows: [[1]]} = sql.("SELECT id FROM users_tokens")
  :ok = Ecto.Migrator.up(repo, version, migration, log: false)

  %{rows: [[1, nil, nil]]} =
    sql.("SELECT id, secure_section_id, secure_resource_id FROM users_tokens")

  IO.puts("Scope migration up/down/up passed; constraints and scoped-token revocation verified.")
after
  case Process.whereis(SecureAssessmentScopeMigrationRepo) do
    nil -> :ok
    pid -> Supervisor.stop(pid)
  end

  :ok = Ecto.Adapters.Postgres.storage_down(config)
end
