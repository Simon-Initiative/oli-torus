defmodule Oli.Repo.Migrations.AddPackageStatus do
  use Ecto.Migration
  def up do
    execute "DELETE FROM part_component_registrations
      WHERE slug = 'janus_carousel';"

      flush()
  end
end
