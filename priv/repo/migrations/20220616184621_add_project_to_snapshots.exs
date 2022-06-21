defmodule Oli.Repo.Migrations.AddProjectToSnapshots do
  use Ecto.Migration

  def change do
    alter table(:snapshots) do
      add :project_id, references(:projects, on_delete: :nothing)
    end

    if direction == :up do
      flush()

      execute """
      UPDATE snapshots SET project_id = sect.base_project_id FROM snapshots snap LEFT JOIN sections sect ON snap.section_id = sect.id;
      """
    end
  end
end
