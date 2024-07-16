defmodule Oli.Repo.Migrations.CreateGetHyperlinksDataFromContent do
  use Ecto.Migration

  def up do
    execute """
    CREATE OR REPLACE FUNCTION get_hyperlink_references_from_revision(content JSONB)
    RETURNS JSONB AS $$
    DECLARE
        result JSONB;
    BEGIN
        WITH RECURSIVE cte AS (
            SELECT jsonb_array_elements(content->'model') AS elem
            UNION ALL
            SELECT jsonb_array_elements(cte.elem->'children')
            FROM cte
            WHERE jsonb_typeof(cte.elem->'children') = 'array'
        )
        SELECT jsonb_agg(
                   jsonb_build_object(
                       'idref', (elem->>'idref')::INT,
                       'href', split_part(elem->>'href', '/', 4)
                   )
               ) INTO result
        FROM cte
        WHERE elem->>'type' = 'a' AND elem->>'linkType' = 'page'
           OR elem->>'type' = 'page_link';
        RETURN result;
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  def down do
    execute """
    DROP FUNCTION IF EXISTS get_hyperlink_references_from_revision(content JSONB);
    """
  end
end
