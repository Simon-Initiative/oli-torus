defmodule Oli.Repo.Migrations.CreateCommunitiesInstitutions do
  use Ecto.Migration

  def change do
    create table(:communities_institutions) do
      add :community_id, references(:communities, on_delete: :delete_all)
      add :institution_id, references(:institutions, on_delete: :delete_all)

      timestamps(type: :timestamptz)
    end

    create unique_index(:communities_institutions, [:community_id, :institution_id],
             name: :index_community_institution
           )
  end
end
