defmodule Oli.Repo.Migrations.RemoveFullHierarchy do
  use Ecto.Migration

  import Ecto.Query, warn: false

  def down do
    alter table(:sections) do
      add :full_hierarchy, :map
    end
  end

  def up do
    alter table(:sections) do
      remove :full_hierarchy
    end
  end
end
