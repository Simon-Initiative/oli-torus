defmodule Oli.Repo.Migrations.FixRevisionParts do
  use Ecto.Migration

  def change do
    # Extract the unique entries in a new table.  This will take records
    # like this:
    #
    # revision_id | part_id | grading_approach
    # 1           | 1       | automatic
    # 1           | 1       | NULL
    # 1           | 1       | NULL
    # 1           | 2       | NULL
    # 1           | 2       | NULL
    # 1           | 2       | NULL
    # 1           | 2       | NULL
    # 1           | 2       | NULL
    # 1           | 2       | NULL
    # 1           | 2       | NULL
    #
    # To:
    # revision_id | part_id | grading_approach
    # 1           | 1       | automatic
    # 1           | 1       | NULL
    # 1           | 2       | NULL
    execute """
    CREATE TABLE temp_revision_parts AS
    SELECT DISTINCT ON (revision_id, grading_approach, part_id) *
    FROM revision_parts;
    """

    # Delete the duplicate entries that have a NULL grading_approach
    # This will take records like this and delete the record with the NULL:
    #
    # revision_id | part_id | grading_approach
    # 1           | 1       | automatic
    # 1           | 1       | NULL
    execute """
    DELETE FROM temp_revision_parts
    WHERE (revision_id, part_id) IN (
        SELECT revision_id, part_id
        FROM temp_revision_parts
        GROUP BY revision_id, part_id
        HAVING COUNT(*) > 1
    )
    AND grading_approach IS NULL;
    """

    # At this point we have a correctly structured copy of revision_parts, so
    # we can backup the origin, drop its indices and rename the new table to
    # to be revision_parts:
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

    execute """
    UPDATE revision_parts SET grading_approach = 'automatic' WHERE grading_approach IS NULL;
    """

    flush()

    # Finally, add back in the indices on the new revision_parts table:
    create unique_index(:revision_parts, [:revision_id, :part_id, :grading_approach])
    create index(:revision_parts, [:revision_id])
  end
end
