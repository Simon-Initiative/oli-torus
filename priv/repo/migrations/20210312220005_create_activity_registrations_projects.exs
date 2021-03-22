defmodule Oli.Repo.Migrations.CreateActivityRegistrationsProjects do
  use Ecto.Migration

  def change do
    create table(:activity_registration_projects, primary_key: false) do
      timestamps(type: :timestamptz)
      add :activity_registration_id, references(:activity_registrations), primary_key: true
      add :project_id, references(:projects), primary_key: true
    end

    create index(:activity_registration_projects, [:activity_registration_id])
    create index(:activity_registration_projects, [:project_id])
    create unique_index(:activity_registration_projects, [:activity_registration_id, :project_id], name: :index_activity_registration_project)
  end
end
