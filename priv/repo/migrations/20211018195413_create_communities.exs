defmodule Oli.Repo.Migrations.CreateCommunities do
  use Ecto.Migration

  def change do
    create table(:communities) do
      add :name, :string, null: false
      add :description, :text
      add :key_contact, :string
      add :prohibit_global_access, :boolean, default: false

      timestamps(type: :timestamptz)
    end

    create unique_index(:communities, [:name])
  end
end
