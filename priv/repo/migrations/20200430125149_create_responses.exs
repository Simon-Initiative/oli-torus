defmodule Oli.Repo.Migrations.CreateResponses do
  use Ecto.Migration

  def change do
    create table(:responses) do
      add :input_value, :map
      add :current, :boolean, default: false, null: false
      add :interaction_id, references(:interactions, on_delete: :nothing)
      add :problem_attempt_id, references(:problem_attempts, on_delete: :nothing)

      timestamps()
    end

    create index(:responses, [:interaction_id])
    create index(:responses, [:problem_attempt_id])
  end
end
