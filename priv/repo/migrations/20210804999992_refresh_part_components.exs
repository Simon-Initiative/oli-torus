defmodule Oli.Repo.Migrations.RefreshPartComponents do
  use Ecto.Migration

  def change do
    alter table(:part_component_registrations) do
      add :author, :string
    end

    flush()

    execute "DELETE FROM part_component_registrations;"

    flush()
  end
end
