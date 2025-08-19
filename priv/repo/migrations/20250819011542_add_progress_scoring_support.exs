defmodule Oli.Repo.Migrations.AddProgressScoringSupport do
  use Ecto.Migration

  def change do
    # Add progress_scoring_settings JSONB column to sections table
    alter table(:sections) do
      add :progress_scoring_settings, :map, default: %{"enabled" => false}
    end

    # Create progress_grade_sync_logs table
    create table(:progress_grade_sync_logs) do
      add :section_id, references(:sections, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :progress_percentage, :float, null: false
      add :score, :float, null: false
      add :out_of, :float, null: false
      add :sync_status, :string, null: false
      add :error_details, :text
      add :attempt_number, :integer, default: 1

      timestamps()
    end

    # Create indexes for efficient querying
    create index(:progress_grade_sync_logs, [:section_id, :user_id])
    create index(:progress_grade_sync_logs, [:section_id, :sync_status])
    create index(:progress_grade_sync_logs, [:inserted_at])
  end
end
