defmodule Oli.Repo.Migrations.AddProjectToSnapshots do
  use Ecto.Migration

  def change do
    alter table(:snapshots) do
      add :project_id, references(:projects, on_delete: :nothing), null: true, default: nil
    end
  end
end
