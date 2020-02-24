defmodule Oli.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :first_name, :string
      add :last_name, :string
      add :email, :string
      add :provider, :string
      add :token, :string

      timestamps()
    end

  end
end
