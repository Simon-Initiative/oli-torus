defmodule Oli.Repo.Migrations.RemixMaterials do
  use Ecto.Migration

  def change do
    create unique_index(:sections_projects_publications, [:section_id, :project_id])
  end
end
