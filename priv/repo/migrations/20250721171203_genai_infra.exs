defmodule Oli.Repo.Migrations.GenaiInfra do
  use Ecto.Migration

  def up do
    create table(:registered_models) do
      add :name, :string, null: false
      add :provider, :string, null: false
      add :model, :string, null: false
      add :url_template, :string, null: false
      add :api_key, :binary
      add :secondary_api_key, :binary
      add :timeout, :integer, default: 8000, null: false
      add :recv_timeout, :integer, default: 60000, null: false

      timestamps(type: :timestamptz)
    end

    create table(:completions_service_configs) do
      add :name, :string, null: false
      add :primary_model_id, references(:registered_models, on_delete: :nothing), null: false
      add :backup_model_id, references(:registered_models, on_delete: :nothing), null: true

      timestamps(type: :timestamptz)
    end

    create table(:gen_ai_feature_configs) do
      add :feature, :string, null: false

      add :service_config_id, references(:completions_service_configs, on_delete: :nothing),
        null: false

      add :section_id, references(:sections, on_delete: :nothing)

      timestamps(type: :timestamptz)
    end

    create index(:gen_ai_feature_configs, [:section_id, :feature], unique: true)
  end

  def down do
    drop table(:gen_ai_feature_configs)
    drop table(:completions_service_configs)
    drop table(:registered_models)
  end
end
