defmodule Oli.Repo.Migrations.GenaiInfra do
  use Ecto.Migration

  def change do
    create table(:registered_models) do
      add :name, :string, null: false
      add :provider, :string, null: false
      add :model, :string, null: false
      add :url_template, :string, null: false
      add :api_key, :string
      add :secondary_api_key, :string
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

    open_ai_key = System.get_env("OPENAI_API_KEY")
    open_ai_org_key = System.get_env("OPENAI_ORG_KEY")
    anthropic_api_key = System.get_env("ANTHROPIC_API_KEY")

    # Insert the record for an OpenAI registered model, the NULL provider, and the Claude model.
    if open_ai_key do
      execute("""
      INSERT INTO registered_models
        (name, provider, model, url_template, api_key,
        secondary_api_key, inserted_at, updated_at)
      VALUES
        ('openai-gpt4', 'open_ai', 'gpt-4-1106-preview', 'https://api.openai.com',
        '#{open_ai_key}', '#{open_ai_org_key}', NOW(), NOW());
      """)
    end

    if anthropic_api_key do
      execute("""
      INSERT INTO registered_models
        (name, provider, model, url_template, api_key,
        secondary_api_key, inserted_at, updated_at)
      VALUES
        ('claude', 'claude', 'claude-3-haiku-20240307', 'https://api.anthropic.com/v1/messages',
        '#{anthropic_api_key}', NULL, NOW(), NOW());
      """)
    end

    execute("""
    INSERT INTO registered_models
      (name, provider, model, url_template, api_key,
       secondary_api_key, inserted_at, updated_at)
    VALUES
      ('null', 'null', 'null', 'https://www.example.com',
       NULL, NULL, NOW(), NOW());
    """)

    # And now a basic service config based only on the OpenAI model
    execute("""
    INSERT INTO completions_service_configs
      (name, primary_model_id, backup_model_id,
        inserted_at, updated_at)
    VALUES
      ('standard-no-backup',
        (SELECT id FROM registered_models WHERE id = 1),
        NULL,
        NOW(), NOW());
    """)

    # Finally, insert the feature config defaults for the student dialogue and instructor dashboard
    execute("""
    INSERT INTO gen_ai_feature_configs
      (feature, service_config_id, section_id, inserted_at, updated_at)
    VALUES
      ('student_dialogue',
        (SELECT id FROM completions_service_configs WHERE name = 'standard-no-backup'),
        NULL,
        NOW(), NOW()),
      ('instructor_dashboard',
        (SELECT id FROM completions_service_configs WHERE name = 'standard-no-backup'),
        NULL,
        NOW(), NOW());
    """)
  end
end
