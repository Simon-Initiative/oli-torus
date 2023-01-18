defmodule Oli.Repo.Migrations.UpdateProjectSectionAddCustomization do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :customizations, :map
    end

    alter table(:sections) do
      add :customizations, :map
    end
  end
end
