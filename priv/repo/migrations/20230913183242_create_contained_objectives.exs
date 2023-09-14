defmodule Oli.Repo.Migrations.CreateContainedObjectives do
  use Ecto.Migration

  def change do
    create table(:contained_objectives) do
      add(:section_id, references(:sections, on_delete: :delete_all))
      add(:container_id, references(:resources))
      add(:objective_id, references(:resources))

      timestamps(type: :timestamptz)
    end

    create(unique_index(:contained_objectives, [:section_id, :container_id, :objective_id]))
    create(index(:contained_objectives, [:container_id]))
  end
end
