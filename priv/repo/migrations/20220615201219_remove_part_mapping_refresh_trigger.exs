defmodule Oli.Repo.Migrations.RemovePartMappingRefreshTrigger do
  use Ecto.Migration

  def up do
    drop_trigger()
  end

  def down do
    drop_trigger()

    user = get_current_db_user()
    create_trigger(user)
    refresh_materialized_view()
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
