defmodule Oli.Repo.Migrations.RemoveResourceToContainerMap do
  use Ecto.Migration

  def up do
    alter table(:sections) do
      remove :resource_to_container_map, :map
    end
  end

  def down do
    alter table(:sections) do
      add :resource_to_container_map, :map
    end
  end
end
