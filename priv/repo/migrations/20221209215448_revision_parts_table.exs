defmodule Oli.Repo.Migrations.RevisionPartsTable do
  use Ecto.Migration

  def change do
    execute """
    CREATE TABLE revision_parts AS SELECT * FROM part_mapping;
    """

    flush()

    create unique_index(:revision_parts, [:revision_id, :part_id, :grading_approach])
    create index(:revision_parts, [:revision_id])

    execute """
    DROP INDEX IF EXISTS part_id_revision_id;
    """

    execute """
    DROP INDEX IF EXISTS revision_id_index;
    """

    execute """
    DROP MATERIALIZED VIEW IF EXISTS public.part_mapping;
    """

    flush()
  end
end
