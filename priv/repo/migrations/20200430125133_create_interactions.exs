defmodule Oli.Repo.Migrations.CreateInteractions do
  use Ecto.Migration

  def change do
    create table(:interactions) do
      add :interaction_guid, :string
      add :name, :string
      add :problem_attempt_id, references(:problem_attempts, on_delete: :nothing)

      timestamps()
    end

    create index(:interactions, [:problem_attempt_id])
  end
end
