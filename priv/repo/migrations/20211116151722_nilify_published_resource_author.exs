defmodule Oli.Repo.Migrations.NilifyPublishedResourceAuthor do
  use Ecto.Migration

  def up do
    drop(constraint(:published_resources, "published_resources_locked_by_id_fkey"))

    alter table(:published_resources) do
      modify(:locked_by_id, references(:authors, on_delete: :nilify_all))
    end
  end

  def down() do
    drop(constraint(:published_resources, "published_resources_locked_by_id_fkey"))

    alter table(:published_resources) do
      modify(:locked_by_id, references(:authors, on_delete: :nothing))
    end
  end
end
