defmodule Oli.Repo.Migrations.UpdateCapiPartRegistrations do
  use Ecto.Migration

  def change do
    execute "update part_component_registrations
    set title='Iframe',description='A webpage displayed in an iframe, or a simulation,
    virtual tour, or component that uses CAPI.'
    where slug='janus_capi_iframe' and delivery_element='janus-capi-iframe'"
    flush()
  end
end
