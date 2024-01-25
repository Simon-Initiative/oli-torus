defmodule Oli.Repo.Migrations.FixRevisionParts do
  use Ecto.Migration

  def change do

    execute """
    CREATE TABLE temp_revision_parts AS
    SELECT DISTINCT ON (revision_id, grading_approach, part_id) *
    FROM revision_parts;
    """

    execute """
    ALTER TABLE revision_parts RENAME TO backup_revision_parts;
    """

    execute """
    DROP INDEX revision_parts_revision_id_index;
    """

    execute """
    DROP INDEX revision_parts_revision_id_part_id_grading_approach_index;
    """

    execute """
    ALTER TABLE temp_revision_parts RENAME TO revision_parts;
    """

    flush()

    create unique_index(:revision_parts, [:revision_id, :part_id, :grading_approach])
    create index(:revision_parts, [:revision_id])
  end

end
