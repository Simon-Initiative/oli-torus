defmodule Oli.Repo.Migrations.AttemptStates do
  use Ecto.Migration

  alias Oli.Repo.Migrations.OptimizationInfra

  def change do
    alter table(:part_attempts) do
      add :lifecycle_state, :string, default: "active", null: false
      add :date_submitted, :utc_datetime
      add :grading_approach, :string, default: "automatic", null: false
    end

    alter table(:activity_attempts) do
      add :lifecycle_state, :string, default: "active", null: false
      add :date_submitted, :utc_datetime
    end

    alter table(:resource_attempts) do
      add :lifecycle_state, :string, default: "active", null: false
      add :date_submitted, :utc_datetime
    end

    flush()

    execute "UPDATE part_attempts SET lifecycle_state = 'active' WHERE date_evaluated IS NULL;"

    execute "UPDATE part_attempts SET lifecycle_state = 'evaluated' WHERE date_evaluated IS NOT NULL;"

    execute "UPDATE activity_attempts SET lifecycle_state = 'active' WHERE date_evaluated IS NULL;"

    execute "UPDATE activity_attempts SET lifecycle_state = 'evaluated' WHERE date_evaluated IS NOT NULL;"

    execute "UPDATE resource_attempts SET lifecycle_state = 'active' WHERE date_evaluated IS NULL;"

    execute "UPDATE resource_attempts SET lifecycle_state = 'evaluated' WHERE date_evaluated IS NOT NULL;"

    execute "UPDATE part_attempts SET grading_approach = 'automatic';"
    execute "UPDATE part_attempts SET date_submitted = date_evaluated;"
    execute "UPDATE activity_attempts SET date_submitted = date_evaluated;"
    execute "UPDATE resource_attempts SET date_submitted = date_evaluated;"

    OptimizationInfra.drop_trigger()
    drop_materialized_view()

    user = OptimizationInfra.get_current_db_user()
    create_materialized_view(user)
    OptimizationInfra.create_trigger(user)
    OptimizationInfra.refresh_materialized_view()

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
end
