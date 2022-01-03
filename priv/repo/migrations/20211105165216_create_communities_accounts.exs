defmodule Oli.Repo.Migrations.CreateCommunitiesAccounts do
  use Ecto.Migration

  def change do
    create table(:communities_accounts) do
      add :community_id, references(:communities, on_delete: :delete_all)
      add :author_id, references(:authors, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)
      add :is_admin, :boolean, default: false, null: false

      timestamps(type: :timestamptz)
    end

    create unique_index(:communities_accounts, [:community_id, :author_id], name: :index_community_author)
    create unique_index(:communities_accounts, [:community_id, :user_id], name: :index_community_user)
  end
end
