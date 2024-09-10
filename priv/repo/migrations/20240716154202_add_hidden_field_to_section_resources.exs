defmodule Oli.Repo.Migrations.AddHiddenFieldToSectionResources do
  use Ecto.Migration

  def change do
    alter table(:section_resources) do
      add :hidden, :boolean, default: false
    end
  end
end
