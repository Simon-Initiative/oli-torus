defmodule Oli.Repo.Migrations.AddSectionSlug do
  use Ecto.Migration

  def change do

    alter table(:sections) do
      add :slug, :string
    end

    create unique_index(:sections, [:slug], name: :index_slug_sections)
  end
end
