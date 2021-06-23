defmodule Oli.Repo.Migrations.RemoveJanusCarousel do
  use Ecto.Migration
  def change do
    execute "DELETE FROM part_component_registrations
      WHERE delivery_element = 'janus-carousel';"

      flush()
  end
end
