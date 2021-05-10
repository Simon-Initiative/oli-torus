defmodule Oli.Repo.Migrations.AddIndices do
  use Ecto.Migration

  def change do
    create index(:publications, [:published, :project_id])
    create index(:published_resources, [:publication_id])
    create index(:published_resources, [:resource_id])

    create unique_index(:published_resources, [:publication_id, :resource_id, :revision_id],
             name: :index_published_resources
           )
  end
end
