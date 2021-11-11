defmodule Oli.Repo.Migrations.ResourceGatingIndex do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add :resource_gating_index, :map, default: %{}, null: false
    end
  end
end
