defmodule Oli.Repo.Migrations.CreateLtiLaunchAttempts do
  use Ecto.Migration

  def change do
    create table(:lti_launch_attempts) do
      add :state_token, :string, null: false
      add :nonce, :string, null: false
      add :flow_mode, :string, null: false
      add :transport_method, :string, null: false
      add :lifecycle_state, :string, null: false
      add :failure_classification, :string
      add :handoff_type, :string

      add :issuer, :string
      add :client_id, :string
      add :deployment_id, :string
      add :context_id, :string
      add :resource_link_id, :string
      add :message_type, :string
      add :target_link_uri, :string
      add :roles, {:array, :string}, null: false, default: []
      add :launch_presentation, :map, null: false, default: %{}

      add :resolved_section_id, :integer
      add :user_id, references(:users, on_delete: :nilify_all)

      add :expires_at, :utc_datetime, null: false
      add :launched_at, :utc_datetime
      add :consumed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:lti_launch_attempts, [:state_token])
    create index(:lti_launch_attempts, [:expires_at])
    create index(:lti_launch_attempts, [:lifecycle_state])
    create index(:lti_launch_attempts, [:issuer, :client_id, :deployment_id])
    create index(:lti_launch_attempts, [:user_id])
  end
end
