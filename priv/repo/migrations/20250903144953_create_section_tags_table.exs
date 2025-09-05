defmodule Oli.Repo.Migrations.CreateSectionTagsTable do
  use Ecto.Migration

  def change do
    create table(:section_tags, primary_key: false) do
      add :section_id, references(:sections, on_delete: :delete_all), primary_key: true
      add :tag_id, references(:tags, on_delete: :delete_all), primary_key: true
      timestamps(type: :utc_datetime)
    end

    create index(:section_tags, [:section_id])
    create index(:section_tags, [:tag_id])
  end
end
