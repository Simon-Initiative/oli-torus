defmodule Oli.Repo.Migrations.CreateInstitutions do
  use Ecto.Migration

  def change do
    create table(:institutions) do
      add :name, :string
      add :country_code, :string
      add :institution_email, :string
      add :institution_url, :string
      add :timezone, :string

      timestamps()
    end

  end
end
