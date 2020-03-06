defmodule Oli.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string
      add :first_name, :string
      add :last_name, :string
      add :provider, :string
      add :token, :string
      add :password, :string
      add :email_verified, :boolean

      timestamps()
    end

  end
end
