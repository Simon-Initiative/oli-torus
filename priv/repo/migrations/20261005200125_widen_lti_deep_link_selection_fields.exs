defmodule Oli.Repo.Migrations.WidenLtiDeepLinkSelectionFields do
  use Ecto.Migration

  def up do
    alter table(:lti_section_resource_deep_links) do
      modify :url, :text
      modify :title, :text
      modify :text, :text
    end
  end

  def down do
    # Refuse a rollback that would discard tool-supplied selection metadata.
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM lti_section_resource_deep_links
        WHERE char_length(url) > 255 OR char_length(title) > 255 OR char_length(text) > 255
      ) THEN
        RAISE EXCEPTION 'Cannot restore 255-character LTI selection fields while longer values exist';
      END IF;
    END $$;
    """

    alter table(:lti_section_resource_deep_links) do
      modify :url, :string
      modify :title, :string
      modify :text, :string
    end
  end
end
