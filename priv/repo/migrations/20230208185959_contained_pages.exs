defmodule Oli.Repo.Migrations.ContainedPages do
  use Ecto.Migration

  def change do
    create table(:contained_pages) do
      add :container_id, references(:section_resources)
      add :page_id, references(:section_resources)

      timestamps(type: :timestamptz)
    end

    create unique_index(:contained_pages, [:container_id, :page_id])
    create index(:contained_pages, [:container_id])
  end
end
