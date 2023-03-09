defmodule Oli.Repo.Migrations.AddAnonymousFieldToPostsTable do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :anonymous, :boolean, default: false
    end
  end
end
