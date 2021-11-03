defmodule Oli.Repo.Migrations.CreateCommunities do
  use Ecto.Migration

  def change do
    create table(:communities) do
      add :name, :string, null: false
      add :description, :text
      add :key_contact, :string
      add :global_access, :boolean, default: true, null: false

      timestamps(type: :timestamptz)
    end

    create unique_index(:communities, [:name])
  end
end
