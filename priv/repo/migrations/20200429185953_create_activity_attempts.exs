defmodule Oli.Repo.Migrations.CreateActivityAttempts do
  use Ecto.Migration

  def change do
    create table(:activity_attempts) do
      add :attempt_number, :integer
      add :deadline, :utc_datetime
      add :last_accessed, :utc_datetime
      add :date_completed, :utc_datetime
      add :date_submitted, :utc_datetime
      add :late_submission, :boolean, default: false, null: false
      add :accepted, :boolean, default: false, null: false
      add :processed_by, :string
      add :date_processed, :utc_datetime
      add :activity_access_id, references(:activity_access)

      timestamps(type: :timestamptz)
    end

    create index(:activity_attempts, [:activity_access_id])
  end
end
