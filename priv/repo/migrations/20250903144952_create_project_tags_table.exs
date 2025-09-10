defmodule Oli.Repo.Migrations.CreateProjectTagsTable do
  use Ecto.Migration

  def change do
    create table(:project_tags, primary_key: false) do
      add :project_id, references(:projects, on_delete: :delete_all), primary_key: true
      add :tag_id, references(:tags, on_delete: :delete_all), primary_key: true
      timestamps(type: :utc_datetime)
    end

    create index(:project_tags, [:project_id])
    create index(:project_tags, [:tag_id])
  end
end
