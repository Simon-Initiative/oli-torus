defmodule Oli.Repo.Migrations.UserReadPosts do
  use Ecto.Migration

  def change do
    create table(:user_read_posts) do
      add :post_id, references(:posts, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps(type: :timestamptz)
    end

    create unique_index(:user_read_posts, [:post_id, :user_id])
  end
end
