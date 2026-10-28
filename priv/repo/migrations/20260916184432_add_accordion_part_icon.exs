defmodule Oli.Repo.Migrations.AddAccordionPartIcon do
  use Ecto.Migration

  def up do
    execute """
    UPDATE part_component_registrations
    SET icon = 'icon-part-accordion.svg', updated_at = NOW()
    WHERE slug = 'janus_accordion'
      AND delivery_element = 'janus-accordion'
    """
  end

  def down do
    execute """
    UPDATE part_component_registrations
    SET icon = '', updated_at = NOW()
    WHERE slug = 'janus_accordion'
      AND delivery_element = 'janus-accordion'
    """
  end
end
