defmodule Oli.Repo.Migrations.CreatePublishers do
  use Ecto.Migration

  def change do
    create table(:publishers) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :address, :string
      add :main_contact, :string
      add :website_url, :string

      timestamps(type: :timestamptz)
    end

    create unique_index(:publishers, [:name])
  end
end
