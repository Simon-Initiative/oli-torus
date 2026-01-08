defmodule Oli.Repo.Migrations.FixPartMappingRefresh do
  use Ecto.Migration

  def change do
    flush()

    drop_trigger()
    drop_materialized_view()

    create_materialized_view()
    create_trigger()
    refresh_materialized_view()

    flush()
  end

  def drop_materialized_view() do
    execute """
    DROP INDEX IF EXISTS part_id_revision_id;
    """

    execute """
    DROP INDEX IF EXISTS revision_id_index;
    """

    execute """
    DROP MATERIALIZED VIEW IF EXISTS public.part_mapping;
    """
  end

  def create_materialized_view() do
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS public.part_mapping
    TABLESPACE pg_default
    AS
    SELECT DISTINCT t.parts->>'id' as part_id, t.parts->>'gradingApproach' as grading_approach, t.revision_id as revision_id FROM (
      SELECT jsonb_path_query(r.content, '$."authoring"."parts"[*]') as parts,
        r.id as revision_id
      FROM published_resources pr
        LEFT JOIN publications p ON p.id = pr.publication_id
        LEFT JOIN revisions r ON r.id = pr.revision_id
      WHERE r.resource_type_id = 3 AND p.published IS NOT NULL) t
    WITH DATA;
    """

    execute """
    ALTER TABLE IF EXISTS public.part_mapping
    OWNER TO CURRENT_USER;
    """

    execute """
    CREATE UNIQUE INDEX part_id_revision_id_grading
    ON public.part_mapping USING btree
    (part_id COLLATE pg_catalog."default", revision_id, grading_approach)
    TABLESPACE pg_default;
    """

    execute """
    CREATE INDEX part_id_revision_id
    ON public.part_mapping USING btree
    (part_id COLLATE pg_catalog."default", revision_id)
    TABLESPACE pg_default;
    """

    execute """
    CREATE INDEX revision_id_index
    ON public.part_mapping USING btree
    (revision_id)
    TABLESPACE pg_default;
    """
  end

  def drop_trigger() do
    execute """
    DROP TRIGGER IF EXISTS published_resources_tr ON public.published_resources;
    """

    execute "DROP FUNCTION IF EXISTS public.refresh_part_mapping() CASCADE;"
  end

  def create_trigger() do
    execute """
    CREATE OR REPLACE FUNCTION public.refresh_part_mapping()
        RETURNS trigger
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE NOT LEAKPROOF
    AS $BODY$
    BEGIN
        REFRESH MATERIALIZED VIEW CONCURRENTLY part_mapping;
        RETURN NULL;
    END;
    $BODY$;
    """

    execute """
    ALTER FUNCTION public.refresh_part_mapping()
    OWNER TO CURRENT_USER;
    """

    execute """
    CREATE TRIGGER publications_tr
        AFTER UPDATE OR DELETE
        ON public.publications
        FOR EACH STATEMENT
        EXECUTE FUNCTION public.refresh_part_mapping();
    """
  end

  def refresh_materialized_view() do
    execute """
    REFRESH MATERIALIZED VIEW part_mapping;
    """
  end
end
