defmodule Oli.Repo.Migrations.AddTags do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :tags, {:array, :id}, default: [], null: false
    end

    create unique_index(:published_resources, [:publication_id, :revision_id],
             name: :index_published_resources_pub_rev
           )
  end
end
