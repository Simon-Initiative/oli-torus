defmodule Oli.Repo.Migrations.RemixMaterials do
  use Ecto.Migration

  def change do
    create unique_index(:sections_projects_publications, [:section_id, :project_id])

    # Prevent duplicate resource_ids within a section.
    # There are a few pieces of logic built on the assumption that a resource_id
    # is unique within a section. This may change but for now we must ensure that is correct
    create unique_index(:section_resources, [:section_id, :resource_id])
  end
end
