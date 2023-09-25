defmodule Oli.Repo.Migrations.AddBlueprintCategory do
  use Ecto.Migration

  def change do
    alter table(:blueprints) do
      add :category, :string, default: "STEM"
    end
  end
end
