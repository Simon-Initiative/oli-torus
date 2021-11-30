defmodule Oli.Repo.Migrations.CreateCommunitiesVisibilities do
  use Ecto.Migration

  def change do
    create table(:communities_visibilities) do
      add :community_id, references(:communities, on_delete: :delete_all)
      add :project_id, references(:projects, on_delete: :delete_all)
      add :section_id, references(:sections, on_delete: :delete_all)

      timestamps(type: :timestamptz)
    end

    create unique_index(:communities_visibilities, [:community_id, :project_id], name: :index_community_project)
    create unique_index(:communities_visibilities, [:community_id, :section_id], name: :index_community_section)
  end
end
