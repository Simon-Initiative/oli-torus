defmodule Oli.Repo.Migrations.FixPreviousMigration do
  use Ecto.Migration

  def change do

    flush()

    drop_trigger()
    drop_materialized_view()

    user = get_current_db_user()
    create_materialized_view(user)
    create_trigger(user)
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

  def create_materialized_view(user) do
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS public.part_mapping
    TABLESPACE pg_default
    AS
    SELECT DISTINCT btrim(jsonb_path_query(r.content, '$."authoring"."parts"[*]."id"'::jsonpath)::text, '"'::text) AS part_id,
        r.id as revision_id,
        btrim(jsonb_path_query(r.content, '$."authoring"."parts"[*]."gradingApproach"'::jsonpath)::text, '"'::text) AS grading_approach
      FROM published_resources pr
        LEFT JOIN publications p ON p.id = pr.publication_id
        LEFT JOIN revisions r ON r.id = pr.revision_id
      WHERE r.resource_type_id = 3 AND p.published IS NOT NULL
      ORDER BY r.id, (btrim(jsonb_path_query(r.content, '$."authoring"."parts"[*]."id"'::jsonpath)::text, '"'::text))
    WITH DATA;
    """

    execute """
    ALTER TABLE IF EXISTS public.part_mapping
    OWNER TO #{user};
    """

    execute """
    CREATE UNIQUE INDEX part_id_revision_id
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


  def get_current_db_user() do
    case System.get_env("DATABASE_URL", nil) do
      nil -> "postgres"
      url -> parse_user_from_db_url(url, "postgres")
    end
  end

  def parse_user_from_db_url(url, default) do
    case url do
      "ecto://" <> rest ->
        split = String.split(rest, ":")

        case Enum.count(split) do
          0 -> default
          1 -> default
          _ -> Enum.at(split, 0)
        end

      _ ->
        default
    end
  end

  def drop_trigger() do
    execute """
    DROP TRIGGER IF EXISTS published_resources_tr ON public.published_resources;
    """

    execute "DROP FUNCTION IF EXISTS public.refresh_part_mapping() CASCADE;"
  end

  def create_trigger(user) do
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
    OWNER TO #{user};
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
