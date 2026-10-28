# Acceptance coverage: AC-020.
defmodule Oli.GenAI.ProviderMigrationTest.Repo do
  use Ecto.Repo, otp_app: :oli, adapter: Ecto.Adapters.Postgres
end

defmodule Oli.GenAI.ProviderMigrationTest do
  use ExUnit.Case, async: false
  alias Oli.GenAI.ProviderMigrationTest.Repo, as: MigrationRepo
  alias Oli.Repo.Migrations.AddGenaiProvidersAndTierCapacity, as: Migration
  @version 20_261_027_183_342

  setup do
    unless Code.ensure_loaded?(Migration) do
      Code.require_file(
        "priv/repo/migrations/20261027183342_add_genai_providers_and_tier_capacity.exs"
      )
    end

    config =
      Oli.Repo.config()
      |> Keyword.put(:pool, DBConnection.ConnectionPool)
      |> Keyword.put(:pool_size, 2)

    start_supervised!({MigrationRepo, config})
    schema = "genai_migration_#{System.unique_integer([:positive])}"
    MigrationRepo.query!("CREATE SCHEMA #{schema}")

    on_exit(fn ->
      ExUnit.CaptureLog.capture_log(fn ->
        Ecto.Adapters.SQL.Sandbox.unboxed_run(Oli.Repo, fn ->
          Oli.Repo.query!("DROP SCHEMA #{schema} CASCADE", [], log: false)
        end)
      end)
    end)

    MigrationRepo.query!(
      "CREATE TABLE #{schema}.registered_models (id bigserial PRIMARY KEY, name text, provider text, model text, url_template text, api_key bytea, secondary_api_key bytea)"
    )

    MigrationRepo.query!(
      "CREATE TABLE #{schema}.completions_service_configs (id bigserial PRIMARY KEY, name text, primary_model_id bigint, secondary_model_id bigint, backup_model_id bigint)"
    )

    %{schema: schema}
  end

  test "single Provider migration copies the first keyed model and rollback preserves all legacy values",
       %{schema: schema} do
    {:ok, first_key} = Oli.Encrypted.Binary.dump("first-secret")
    {:ok, second_key} = Oli.Encrypted.Binary.dump("second-secret")
    {:ok, organization} = Oli.Encrypted.Binary.dump("first-organization")
    insert(schema, "no key", "null", "http://legacy.invalid", nil, nil)
    insert(schema, "first keyed", "open_ai", "https://first.example", first_key, organization)
    insert(schema, "second keyed", "claude", "https://second.example", second_key, nil)
    before = MigrationRepo.query!("SELECT * FROM #{schema}.registered_models ORDER BY id").rows
    assert :ok = migrate(schema, :up)

    assert [["OpenAI production", "open_ai", "https://first.example", ^first_key, ^organization]] =
             MigrationRepo.query!(
               "SELECT name, adapter, base_url, api_key, organization_key FROM #{schema}.gen_ai_providers"
             ).rows

    assert [[3, 1, 1]] =
             MigrationRepo.query!(
               "SELECT COUNT(provider_id), COUNT(DISTINCT provider_id), COUNT(*) FILTER (WHERE health_check) FROM #{schema}.registered_models"
             ).rows

    assert [[1]] =
             MigrationRepo.query!("SELECT id FROM #{schema}.registered_models WHERE health_check").rows

    # Migrated metadata does not rewrite model-specific adapters, endpoints or keys.
    assert :ok = migrate(schema, :down)

    assert before ==
             MigrationRepo.query!("SELECT * FROM #{schema}.registered_models ORDER BY id").rows

    assert [[nil]] = MigrationRepo.query!("SELECT to_regclass('#{schema}.gen_ai_providers')").rows
  end

  test "missing credentials remain explicit and an empty installation still gets exactly one Provider",
       %{schema: schema} do
    assert :ok = migrate(schema, :up)

    assert [["OpenAI production", nil]] =
             MigrationRepo.query!("SELECT name, api_key FROM #{schema}.gen_ai_providers").rows

    assert :ok = migrate(schema, :down)
    insert(schema, "without key", "open_ai", "http://legacy.invalid", nil, nil)
    assert :ok = migrate(schema, :up)

    assert [[1, true]] =
             MigrationRepo.query!(
               "SELECT provider_id, health_check FROM #{schema}.registered_models"
             ).rows

    assert [[nil]] = MigrationRepo.query!("SELECT api_key FROM #{schema}.gen_ai_providers").rows
    assert :ok = migrate(schema, :down)
  end

  defp insert(schema, name, adapter, endpoint, key, secondary) do
    MigrationRepo.query!(
      "INSERT INTO #{schema}.registered_models (name, provider, model, url_template, api_key, secondary_api_key) VALUES ($1,$2,'test-model',$3,$4,$5)",
      [name, adapter, endpoint, key, secondary]
    )
  end

  defp migrate(schema, :up),
    do:
      Ecto.Migrator.up(MigrationRepo, @version, Migration,
        prefix: schema,
        log: false,
        log_migrations_sql: false
      )

  defp migrate(schema, :down),
    do:
      Ecto.Migrator.down(MigrationRepo, @version, Migration,
        prefix: schema,
        log: false,
        log_migrations_sql: false
      )
end
