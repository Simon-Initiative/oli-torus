defmodule Oli.Repo.Migrations.DropPublicationScope do
  use Ecto.Migration

  execute("""
  update part_component_registrations set title='Slider (Numeric)' where slug = 'janus_slider'  and delivery_element ='janus-slider'
  """)
end
