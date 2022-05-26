defmodule Oli.Repo.Migrations.UpdateSectionsAddDisplayCurriculumItemNumbering do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add :display_curriculum_item_numbering, :boolean, default: true, null: false
    end
  end
end
