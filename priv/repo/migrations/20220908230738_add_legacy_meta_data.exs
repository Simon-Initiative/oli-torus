defmodule Oli.Repo.Migrations.AddLegacyMetaData do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :legacy, :map
    end

    alter table(:projects) do
      add :legacy_svn_root, :string
    end

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
        project_id bigint,
        pub_id bigint,
        author_id bigint,
        batch_size bigint)
          RETURNS SETOF bigint
          LANGUAGE 'plpgsql'
          COST 100
          VOLATILE PARALLEL UNSAFE
          ROWS 1000
      AS $BODY$
      DECLARE
            currentMax bigint;
            resourceId bigint;
          revisionId bigint;
          BEGIN
            SELECT MAX(revision_id) FROM published_resources pr WHERE pr.publication_id = pub_id INTO STRICT currentMax;
            FOR i in 1..batch_size LOOP
              INSERT INTO resources (inserted_at, updated_at) VALUES (current_timestamp, current_timestamp) RETURNING id INTO STRICT resourceId;
              INSERT INTO projects_resources (project_id, resource_id, inserted_at, updated_at) VALUES (project_id, resourceId, current_timestamp, current_timestamp);
              INSERT INTO revisions (
                deleted, content, children, tags, objectives, graded, max_attempts, recommended_attempts, time_limit, scope, retake_mode,
                author_id, resource_id, resource_type_id, scoring_strategy_id, activity_type_id, inserted_at, updated_at)
                VALUES (
                  false, '{}'::jsonb, '{}'::bigint[], '{}'::bigint[], '{}'::jsonb, false, 5, 5, 0, 'embedded', 'normal',
                  author_id, resourceId, 1, 1, 1, current_timestamp, current_timestamp) RETURNING id INTO STRICT revisionId;
              INSERT INTO published_resources (publication_id, resource_id, revision_id, inserted_at, updated_at)
                VALUES (pub_id, resourceId, revisionId, current_timestamp, current_timestamp);


            END LOOP;

            RETURN QUERY SELECT revision_id FROM published_resources pr WHERE pr.publication_id = pub_id and pr.revision_id > currentMax;

          END;
      $BODY$;
    """

    execute """
    ALTER FUNCTION public.create_resource_batch(bigint, bigint, bigint, bigint) OWNER TO #{user};
    """
  end
end
