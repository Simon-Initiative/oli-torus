defmodule Oli.Repo.Migrations.CreateGetActivityReferencesFunction do
  use Ecto.Migration

  @doc """
  Defines a recursive function to search for activities within the content of a page.

  The migration creates two PostgreSQL functions:

  1. `get_activity_references(content jsonb)`: This function processes the JSONB content recursively.
     It searches for objects with the type `activity-reference` and returns their `activity_id`.
     If the object has children, it recursively processes each child.

  2. `get_all_activity_references(content jsonb)`: This function processes the top-level `model` array
     in the JSONB content and uses `get_activity_references` to find all `activity_id` values in the content.

  These functions help in extracting all activity references from nested content structures in a page.
  """
  def up do
    execute """
        CREATE OR REPLACE FUNCTION get_activity_references(content jsonb)
        RETURNS TABLE(activity_id int) AS $$
        DECLARE
            child jsonb;
        BEGIN
            -- Process the current level
            IF content @> '{"type": "activity-reference"}' THEN
                RETURN QUERY SELECT (content->>'activity_id')::int;
            END IF;

            -- Process children if exists
            FOR child IN SELECT * FROM jsonb_array_elements(content->'children')
            LOOP
                RETURN QUERY SELECT * FROM get_activity_references(child);
            END LOOP;

            RETURN;
        END;
        $$ LANGUAGE plpgsql;
    """

    flush()

    execute """
    CREATE OR REPLACE FUNCTION get_all_activity_references(content jsonb)
    RETURNS TABLE(activity_id int) AS $$
    BEGIN
        RETURN QUERY
        SELECT ar.activity_id
        FROM jsonb_array_elements(content->'model') AS model_element,
        LATERAL get_activity_references(model_element) AS ar;
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  def down do
    execute """
    DROP FUNCTION IF EXISTS get_all_activity_references(content jsonb);
    DROP FUNCTION IF EXISTS get_activity_references(content jsonb);
    """
  end
end
