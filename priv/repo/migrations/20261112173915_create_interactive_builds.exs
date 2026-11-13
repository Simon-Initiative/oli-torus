defmodule Oli.Repo.Migrations.CreateInteractiveBuilds do
  use Ecto.Migration

  def up do
    create table(:interactive_builds, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :resource_id, references(:resources, on_delete: :delete_all), null: false
      add :author_id, references(:authors, on_delete: :delete_all), null: false
      add :lock_id, :bigint, null: false
      add :status, :string, null: false, default: "queued"
      add :inputs, :map, null: false
      add :session_id, :text
      add :handoff, :map, null: false, default: %{}
      add :error, :text
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:interactive_builds, [:project_id, :resource_id],
             name: :interactive_builds_one_active,
             where: "status IN ('queued', 'launching', 'running')"
           )
  end

  def down do
    drop table(:interactive_builds)
  end
end
