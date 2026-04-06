defmodule Oli.Repo.Migrations.AddSectionTileLayoutsToInstructorDashboardStates do
  use Ecto.Migration

  def change do
    alter table(:instructor_dashboard_states) do
      add :section_tile_layouts, :map, default: %{}, null: false
    end
  end
end
