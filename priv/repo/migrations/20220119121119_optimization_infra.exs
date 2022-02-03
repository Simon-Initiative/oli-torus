defmodule Oli.Repo.Migrations.OptimizationInfra do
  use Ecto.Migration

  def up do
    # drop these items if they somehow happen to exist
    drop_stored_procedure()
    drop_trigger()
    drop_materialized_view()

    user = get_current_db_user()

    create_materialized_view(user)
    create_trigger(user)
    create_stored_procedure(user)

    refresh_materialized_view()
  end

  def down do
    drop_stored_procedure()
    drop_trigger()
    drop_materialized_view()
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

  def drop_materialized_view() do
    execute """
    DROP MATERIALIZED VIEW IF EXISTS public.part_mapping;
    """
  end

  def drop_trigger() do
    execute """
    DROP TRIGGER IF EXISTS published_resources_tr ON public.published_resources;
    """

    execute "DROP FUNCTION IF EXISTS public.refresh_part_mapping() CASCADE;"
  end

  def drop_stored_procedure() do
    execute """
    DROP PROCEDURE IF EXISTS public.create_attempt_hierarchy(integer, character varying);
    """
  end

  def create_materialized_view(user) do
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS public.part_mapping
    TABLESPACE pg_default
    AS
    SELECT DISTINCT btrim(jsonb_path_query(r.content, '$."authoring"."parts"[*]."id"'::jsonpath)::text, '"'::text) AS part_id,
        r.id as revision_id
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

  def create_stored_procedure(user) do
    execute """
    CREATE OR REPLACE PROCEDURE public.create_attempt_hierarchy(
      resource_attempt_id integer,
      section_slug character varying)
    LANGUAGE 'sql'
    AS $BODY$
    INSERT INTO activity_attempts(resource_attempt_id, attempt_guid, attempt_number, revision_id, resource_id, scoreable, inserted_at, updated_at)
    SELECT resource_attempt_id, gen_random_uuid(), 1, sr.id, sr.resource_id, true, now(), now()
    FROM resource_attempts as r
    LEFT JOIN LATERAL jsonb_path_query(r.content, '$.** ? (@.type == "activity-reference" && (!(@.custom.isLayer == true || @.custom.isGroup == true)))."activity_id"') as p ON TRUE
    LEFT JOIN section_resources as secr on secr.resource_id = CAST(p as int)
    LEFT JOIN sections as s on s.id = secr.section_id
    LEFT JOIN sections_projects_publications as spp on spp.section_id = s.id
    LEFT JOIN published_resources as pr on pr.publication_id = spp.publication_id and pr.resource_id = CAST(p as int) and pr.publication_id = spp.publication_id
    LEFT JOIN revisions as sr on sr.id = pr.revision_id
    WHERE r.id = resource_attempt_id and s.slug = section_slug
    UNION
    SELECT resource_attempt_id, gen_random_uuid(), 1, sr.id, sr.resource_id, false, now(), now()
    FROM resource_attempts as r
    LEFT JOIN LATERAL jsonb_path_query(r.content, '$.** ? (@.type == "activity-reference" && (@.custom.isLayer == true || @.custom.isGroup == true))."activity_id"') as p ON TRUE
    LEFT JOIN section_resources as secr on secr.resource_id = CAST(p as int)
    LEFT JOIN sections as s on s.id = secr.section_id
    LEFT JOIN sections_projects_publications as spp on spp.section_id = s.id
    LEFT JOIN published_resources as pr on pr.publication_id = spp.publication_id and pr.resource_id = CAST(p as int) and pr.publication_id = spp.publication_id
    LEFT JOIN revisions as sr on sr.id = pr.revision_id
    WHERE r.id = resource_attempt_id and s.slug = section_slug;

    INSERT INTO part_attempts(part_id, activity_attempt_id, attempt_guid, inserted_at, updated_at, hints, attempt_number)
    SELECT pm.part_id, a.id, gen_random_uuid(), now(), now(), '{}'::varchar[], 1
    FROM activity_attempts as a
    LEFT JOIN part_mapping as pm on a.revision_id = pm.revision_id
    WHERE a.resource_attempt_id = resource_attempt_id;
    $BODY$;
    """

    execute """
    ALTER PROCEDURE public.create_attempt_hierarchy(integer, character varying)
        OWNER TO #{user};
    """

    execute """
    GRANT EXECUTE ON PROCEDURE public.create_attempt_hierarchy(integer, character varying) TO #{user};
    """

    execute """
    GRANT EXECUTE ON PROCEDURE public.create_attempt_hierarchy(integer, character varying) TO PUBLIC;
    """
  end

  def refresh_materialized_view() do
    execute """
    REFRESH MATERIALIZED VIEW part_mapping;
    """
  end
end
