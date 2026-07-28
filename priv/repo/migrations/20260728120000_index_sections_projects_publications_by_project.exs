defmodule Oli.Repo.Migrations.IndexSectionsProjectsPublicationsByProject do
  use Ecto.Migration

  def change do
    create index(:sections_projects_publications, [:project_id, :section_id])
  end
end
