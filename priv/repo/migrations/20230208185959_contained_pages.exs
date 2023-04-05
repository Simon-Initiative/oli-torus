defmodule Oli.Repo.Migrations.ContainedPages do
  use Ecto.Migration

  def change do
    create table(:contained_pages) do
      add :section_id, references(:sections)
      add :container_id, references(:resources)
      add :page_id, references(:resources)
    end

    create unique_index(:contained_pages, [:section_id, :container_id, :page_id])
    create index(:contained_pages, [:container_id])

    alter table(:resource_accesses) do
      add :progress, :float, default: 0.0
    end

    alter table(:section_resources) do
      add :contained_page_count, :integer, default: 0
    end
  end
end
