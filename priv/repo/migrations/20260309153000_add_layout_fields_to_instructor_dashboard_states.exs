defmodule Oli.Repo.Migrations.AddLayoutFieldsToInstructorDashboardStates do
  use Ecto.Migration

  def change do
    alter table(:instructor_dashboard_states) do
      add :section_order, {:array, :text}, default: [], null: false
      add :collapsed_section_ids, {:array, :text}, default: [], null: false
    end
  end
end
