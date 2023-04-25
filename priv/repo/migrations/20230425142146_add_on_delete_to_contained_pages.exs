defmodule Oli.Repo.Migrations.AddOnDeleteToContainedPages do
  use Ecto.Migration

  def up do
    drop(constraint(:contained_pages, "contained_pages_section_id_fkey"))

    alter table(:contained_pages) do
      modify(:section_id, references(:sections, on_delete: :delete_all))
    end
  end

  def down do
    drop(constraint(:contained_pages, "contained_pages_section_id_fkey"))

    alter table(:contained_pages) do
      modify(:section_id, references(:sections, on_delete: :noting))
    end
  end
end
