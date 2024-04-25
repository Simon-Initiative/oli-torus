defmodule Oli.Repo.Migrations.AddHostIdentifierTable do
  use Ecto.Migration

  def change do
    create table(:host_identifier, primary_key: false) do
      add :id, :integer, null: false
      add :host, :string, null: false
      timestamps()
    end

    create constraint("host_identifier", :one_row, check: "id = 1")

    create unique_index(:host_identifier, :id)
    create unique_index(:host_identifier, :host)
  end
end
