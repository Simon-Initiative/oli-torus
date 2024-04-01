defmodule Oli.Repo.Migrations.UserReactionPosts do
  use Ecto.Migration

  def change do
    create table(:user_reaction_posts) do
      add :reaction, :string, default: "like"
      add :post_id, references(:posts, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps(type: :timestamptz)
    end

    create unique_index(:user_reaction_posts, [:reaction, :post_id, :user_id])
  end
end
