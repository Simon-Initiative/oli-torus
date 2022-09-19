defmodule Oli.Repo.Migrations.OptimizedIngest do
  use Ecto.Migration

  def change do
    get_current_db_user()
    |> add_batch_resource_creation_function()
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

  def add_batch_resource_creation_function(user) do
    execute """
    CREATE OR REPLACE FUNCTION public.create_resource_batch(
      proj_id bigint,
      batch_size bigint)
        RETURNS SETOF bigint
        LANGUAGE 'plpgsql'
        COST 100
        VOLATILE PARALLEL UNSAFE
        ROWS 1000

    AS $BODY$
    DECLARE
        resourceId bigint[];
        currentMax bigint;
      BEGIN
        SELECT MAX(pr.resource_id) FROM projects_resources pr WHERE pr.project_id = proj_id INTO STRICT currentMax;

        WITH resources_ins as (
            INSERT INTO resources (inserted_at, updated_at) SELECT UNNEST (array_fill(current_timestamp, ARRAY[batch_size::int])), UNNEST (array_fill(current_timestamp, ARRAY[batch_size::int])) RETURNING id
        )
        SELECT array_agg(id) INTO resourceId FROM resources_ins;

        INSERT INTO projects_resources (project_id, resource_id, inserted_at, updated_at)
          SELECT
            UNNEST (array_fill(proj_id, ARRAY[batch_size::int])),
            UNNEST (resourceId),
            UNNEST (array_fill(current_timestamp, ARRAY[batch_size::int])),
            UNNEST (array_fill(current_timestamp, ARRAY[batch_size::int]));

        RETURN QUERY SELECT pr.resource_id FROM projects_resources pr WHERE pr.project_id = proj_id and pr.resource_id > currentMax;

      END;
    $BODY$;

    """

    execute """
    ALTER FUNCTION public.create_resource_batch(bigint, bigint) OWNER TO #{user};
    """
  end
end
