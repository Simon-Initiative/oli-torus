defmodule Oli.Repo.Migrations.AddPostsTable do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :content, :string, null: false
      add :status, :string, default: "approved", null: false

      add :user_id, references(:users)
      add :section_id, references(:sections)
      add :resource_id, references(:resources)
      add :parent_post_id, references(:posts)
      add :thread_root_id, references(:posts)

      timestamps(type: :timestamptz)
    end

    create index(:posts, [:section_id, :resource_id])
    create index(:posts, [:thread_root_id])
  end
end
