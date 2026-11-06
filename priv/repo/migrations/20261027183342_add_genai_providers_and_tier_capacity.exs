defmodule Oli.Repo.Migrations.AddGenaiProvidersAndTierCapacity do
  use Ecto.Migration

  def up do
    create table(:gen_ai_providers) do
      add :name, :string, null: false
      add :adapter, :string, null: false
      add :base_url, :text
      add :api_key, :binary
      add :organization_key, :binary
      add :enabled, :boolean, default: true, null: false
      add :config_version, :integer, default: 1, null: false
      add :probe_interval_ms, :integer
      add :probe_failure_interval_ms, :integer
      add :probe_deadline_ms, :integer
      add :failure_threshold, :integer
      add :recovery_threshold, :integer
      timestamps(type: :utc_datetime)
    end

    for field <- [
          :probe_interval_ms,
          :probe_failure_interval_ms,
          :probe_deadline_ms,
          :failure_threshold,
          :recovery_threshold
        ] do
      create constraint(:gen_ai_providers, "#{field}_positive",
               check: "#{field} IS NULL OR #{field} > 0"
             )
    end

    alter table(:registered_models) do
      add :provider_id, references(:gen_ai_providers, on_delete: :nothing)
      add :health_check, :boolean, default: false, null: false
    end

    create index(:registered_models, [:provider_id])

    alter table(:completions_service_configs) do
      add :primary_pool_capacity, :integer, default: 100, null: false
      add :secondary_pool_capacity, :integer, default: 100, null: false
      add :backup_pool_capacity, :integer, default: 100, null: false
    end

    for tier <- [:primary, :secondary, :backup] do
      create constraint(:completions_service_configs, "#{tier}_pool_capacity_positive",
               check: "#{tier}_pool_capacity > 0"
             )
    end

    # Copy ciphertext directly, without materializing secrets in migration logs.
    # Credentials are owned exclusively by Providers after the backfill.
    providers = qualified_table("gen_ai_providers")
    models = qualified_table("registered_models")

    execute """
    INSERT INTO #{providers}
      (name, adapter, base_url, api_key, organization_key, inserted_at, updated_at)
    SELECT 'OpenAI production', 'open_ai',
      COALESCE((SELECT url_template FROM #{models}
                WHERE api_key IS NOT NULL AND octet_length(api_key) > 0 ORDER BY id LIMIT 1),
               'https://api.openai.com'),
      (SELECT api_key FROM #{models}
       WHERE api_key IS NOT NULL AND octet_length(api_key) > 0 ORDER BY id LIMIT 1),
      (SELECT secondary_api_key FROM #{models}
       WHERE api_key IS NOT NULL AND octet_length(api_key) > 0 ORDER BY id LIMIT 1),
      NOW(), NOW()
    """

    execute "UPDATE #{models} SET provider_id = (SELECT id FROM #{providers})"

    execute "UPDATE #{models} SET health_check = true WHERE id = (SELECT MIN(id) FROM #{models})"

    alter table(:registered_models) do
      modify :provider_id, :bigint, null: false
      remove :pool_class, :string
      remove :provider, :string
      remove :url_template, :string
      remove :api_key, :binary
      remove :secondary_api_key, :binary
    end
  end

  def down do
    alter table(:registered_models) do
      add :pool_class, :string, null: false, default: "slow"
      add :provider, :string
      add :url_template, :string
      add :api_key, :binary
      add :secondary_api_key, :binary
    end

    for tier <- [:primary, :secondary, :backup] do
      drop constraint(:completions_service_configs, "#{tier}_pool_capacity_positive")
    end

    alter table(:completions_service_configs) do
      remove :backup_pool_capacity
      remove :secondary_pool_capacity
      remove :primary_pool_capacity
    end

    drop index(:registered_models, [:provider_id])

    alter table(:registered_models) do
      remove :health_check
      remove :provider_id
    end

    drop table(:gen_ai_providers)
  end

  defp qualified_table(table) do
    schema = String.replace(prefix() || "public", "\"", "\"\"")
    "\"#{schema}\".\"#{table}\""
  end
end
