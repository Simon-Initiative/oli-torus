defmodule Oli.Repo.Migrations.UpdateCapiPartRegistrations do
  use Ecto.Migration

  def up do
    execute """
    UPDATE part_component_registrations
    SET title = 'Iframe',
        description = 'A webpage displayed in an iframe, or a simulation, virtual tour, or component that uses CAPI.'
    WHERE slug = 'janus_capi_iframe'
      AND delivery_element = 'janus-capi-iframe'
    """
  end

  def down do
    # Replace with actual original values when known
    execute """
    UPDATE part_component_registrations
    SET title = 'CAPI Simulation / VFT / Component',
        description = 'An advanced Simulation, VFT (Virtual Field Trip), or Component that communicates dynamically through the CAPI interface.'
    WHERE slug = 'janus_capi_iframe'
      AND delivery_element = 'janus-capi-iframe'
    """
  end
end
