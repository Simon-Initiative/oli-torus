defmodule Oli.Repo.Migrations.UpdateSnapshotsAddProjectIds do
  use Ecto.Migration

  def up do
    drop index(:snapshots, [:objective_id])
    drop index(:snapshots, [:activity_id])
    drop index(:snapshots, [:section_id])
    drop index(:snapshots, [:part_attempt_id, :objective_id], name: :snapshot_unique_part)

    execute """
    UPDATE snapshots
    SET project_id = sect.base_project_id
    FROM sections sect WHERE sect.id = snapshots.section_id;
    """

    create index(:snapshots, [:objective_id])
    create index(:snapshots, [:activity_id])
    create index(:snapshots, [:section_id])

    create unique_index(:snapshots, [:part_attempt_id, :objective_id], name: :snapshot_unique_part)
  end

  def down do
    execute """
    UPDATE snapshots
    SET project_id = NULL
    """
  end
end
