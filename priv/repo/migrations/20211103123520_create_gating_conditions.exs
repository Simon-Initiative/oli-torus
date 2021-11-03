defmodule Oli.Repo.Migrations.CreateGatingConditions do
  use Ecto.Migration

  def change do
    create table(:gating_conditions) do
      add :type, :string, null: false
      add :data, :map

      add :resource_id, references(:resources)
      add :section_id, references(:sections)
      add :user_id, references(:users)

      timestamps()
    end
  end
end
