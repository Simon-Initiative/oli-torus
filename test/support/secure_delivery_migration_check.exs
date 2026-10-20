# Uses a newly created disposable database; never drops an existing database.
defmodule SecureDeliveryMigrationRepo do
  use Ecto.Repo, otp_app: :oli, adapter: Ecto.Adapters.Postgres
end

unless Mix.env() == :test, do: raise("Migration rehearsal requires MIX_ENV=test")
{:ok, _} = Application.ensure_all_started(:ecto_sql)

config =
  Oli.Repo.config()
  |> Keyword.put(:database, "oli_secure_delivery_policy_migration_check")
  |> Keyword.put(:pool, DBConnection.ConnectionPool)
  |> Keyword.put(:pool_size, 2)
  |> Keyword.delete(:url)

case Ecto.Adapters.Postgres.storage_up(config) do
  :ok -> :ok
  other -> raise("Refusing to reuse or delete rehearsal database: #{inspect(other)}")
end

try do
  {:ok, _pid} = SecureDeliveryMigrationRepo.start_link(config)
  repo = SecureDeliveryMigrationRepo
  sql = fn statement -> Ecto.Adapters.SQL.query!(repo, statement, []) end
  sql.("CREATE TABLE section_resources (id bigserial PRIMARY KEY)")
  sql.("INSERT INTO section_resources DEFAULT VALUES")

  Code.require_file(
    "priv/repo/migrations/20260922153042_add_secure_delivery_to_section_resources.exs"
  )

  policy = Oli.Repo.Migrations.AddSecureDeliveryToSectionResources
  :ok = Ecto.Migrator.up(repo, 20_260_922_153_042, policy, log: false)
  %{rows: [[false]]} = sql.("SELECT secure_delivery FROM section_resources")

  {:error, %Postgrex.Error{postgres: %{code: :not_null_violation}}} =
    Ecto.Adapters.SQL.query(repo, "UPDATE section_resources SET secure_delivery = NULL", [])

  sql.("UPDATE section_resources SET secure_delivery = true")
  %{rows: [[true]]} = sql.("SELECT secure_delivery FROM section_resources")
  :ok = Ecto.Migrator.down(repo, 20_260_922_153_042, policy, log: false)
  %{rows: [[1]]} = sql.("SELECT id FROM section_resources")
  :ok = Ecto.Migrator.up(repo, 20_260_922_153_042, policy, log: false)
  %{rows: [[false]]} = sql.("SELECT secure_delivery FROM section_resources")
  IO.puts("Policy migration up/down/up passed; default and not-null constraint verified.")
after
  case Process.whereis(SecureDeliveryMigrationRepo) do
    nil -> :ok
    pid -> Supervisor.stop(pid)
  end

  :ok = Ecto.Adapters.Postgres.storage_down(config)
end
