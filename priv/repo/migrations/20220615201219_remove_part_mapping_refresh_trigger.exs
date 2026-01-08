defmodule Oli.Repo.Migrations.RemovePartMappingRefreshTrigger do
  use Ecto.Migration

  def up do
    drop_trigger()
  end

  def down do
    drop_trigger()

    create_trigger()
    refresh_materialized_view()
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
