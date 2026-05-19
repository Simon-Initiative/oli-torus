defmodule Oli.Repo.Migrations.CreateInstructorDashboardStates do
  use Ecto.Migration

  def change do
    create table(:instructor_dashboard_states) do
      add :enrollment_id, references(:enrollments, on_delete: :delete_all), null: false
      add :last_viewed_scope, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:instructor_dashboard_states, [:enrollment_id])
  end
end
