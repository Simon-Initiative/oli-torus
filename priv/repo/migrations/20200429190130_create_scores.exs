defmodule Oli.Repo.Migrations.CreateScores do
  use Ecto.Migration

  def change do
    create table(:scores) do
      add :score, :decimal
      add :points, :decimal
      add :out_of, :decimal
      add :date_scored, :utc_datetime
      add :assigned_by, :string
      add :score_explanation, :string
      add :override, :decimal
      add :overridden_by, :string
      add :date_overridden, :utc_datetime
      add :activity_access_id, references(:activity_access)
      add :activity_attempt_id, references(:activity_attempts)
      add :problem_attempt_id, references(:problem_attempts)

      timestamps(type: :timestamptz)
    end

    create index(:scores, [:activity_access_id])
    create index(:scores, [:activity_attempt_id])
    create index(:scores, [:problem_attempt_id])
  end
end
