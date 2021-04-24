defmodule Oli.Repo.Migrations.CreateBrands do
  use Ecto.Migration

  def change do
    create table(:brands) do
      add :name, :string
      add :logo, :string
      add :logo_dark, :string
      add :favicons, :string
      add :favicons_dark, :string

      add :institution_id, references(:institutions, on_delete: :nothing)

      timestamps(type: :timestamptz)
    end

    create index(:brands, [:institution_id])

    alter table(:lti_1p3_registrations) do
      add :brand_id, references(:brands)
    end

    alter table(:sections) do
      add :brand_id, references(:brands)
    end
  end
end
