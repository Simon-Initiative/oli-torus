defmodule Oli.Repo.Migrations.CreateFeedbacks do
  use Ecto.Migration

  def change do
    create table(:feedbacks) do
      add :assigned_by, :string
      add :body, :map
      add :response_id, references(:responses)
      add :activity_access_id, references(:activity_access)

      timestamps(type: :timestamptz)
    end

    create index(:feedbacks, [:problem_attempt_id])
    create index(:feedbacks, [:activity_access_id])
  end
end
