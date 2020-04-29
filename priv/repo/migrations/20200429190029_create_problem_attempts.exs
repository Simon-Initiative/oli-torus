defmodule Oli.Repo.Migrations.CreateProblemAttempts do
  use Ecto.Migration

  def change do
    create table(:problem_attempts) do
      add :attempt_number, :integer
      add :problem_id, :string
      add :correct, :boolean, default: false, null: false
      add :date_evaluated, :utc_datetime
      add :children, {:array, :id}
      add :feedback_visible, :boolean, default: false, null: false
      add :hint_visible, :boolean, default: false, null: false
      add :hint, :map
      add :activity_attempts_id, references(:activity_attempts)
      add :parent_id, references(:problem_attempts)

      timestamps(type: :timestamptz)
    end

    create index(:problem_attempts, [:activity_attempts_id])
    create index(:problem_attempts, [:parent_id])
  end
end
