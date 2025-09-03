defmodule Oli.Repo.Migrations.CreateTagsTable do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :name, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:tags, [:name])
    create index(:tags, [:inserted_at])
  end
end
