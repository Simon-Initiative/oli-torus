defmodule Oli.Repo.Migrations.CreateInstitutions do
  use Ecto.Migration

  def change do
    create table(:institutions) do
      add :institution_email, :string
      add :name, :string
      add :country_code, :string
      add :institution_url, :string
      add :timezone, :string
      add :password, :string

      timestamps()
    end

  end
end
