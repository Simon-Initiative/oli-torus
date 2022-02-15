defmodule Oli.Repo.Migrations.CreateActivityCustomLogs do
  use Ecto.Migration

  def change do
    create table(:custom_activity_logs) do
      add :user_id, references(:users)
      add :section_id, references(:sections)
      add :resource_id, references(:resources)
      add :activity_attempt_id, references(:activity_attempts)
      add :revision_id, references(:revisions)
      add :action, :string
      add :attempt_number, :integer
      add :activity_type, :string
      add :info, :text

      timestamps(type: :timestamptz)
    end

    create index(:custom_activity_logs, [:section_id])
    create index(:custom_activity_logs, [:user_id])
    create index(:custom_activity_logs, [:resource_id])
    create index(:custom_activity_logs, [:activity_attempt_id])
    create index(:custom_activity_logs, [:activity_type])

  end
end
