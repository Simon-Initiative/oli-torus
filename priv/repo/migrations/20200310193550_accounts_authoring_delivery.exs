defmodule Oli.Repo.Migrations.CreateRoles do
  use Ecto.Migration

  def change do
    # accounts

    create table(:system_roles) do
      timestamps()
      add :type, :string
    end

    create table(:project_roles) do
      timestamps()
      add :type, :string
    end

    create table(:section_roles) do
      timestamps()
      add :type, :string
    end

    create table(:users_projects) do
      timestamps()
      add :user_id, references(:users)
      add :project_id, references(:projects)
      add :project_role_id, references(:project_roles)
    end

    create table(:users_sections) do
      timestamps()
      add :user_id, references(:users)
      add :section_id, references(:sections)
      add :section_role_id, references(:section_roles)
    end

    # authoring

    create table(:project_families) do
      timestamps()
      add :slug, :string
    end

    create table(:projects) do
      timestamps()
      add :title, :string
      add :slug, :string
      add :description, :string
      add :version, :string
      add :parent_project_id, references(:projects)
      add :project_family_id, references(:project_families)
    end

    create table(:resource_types) do
      timestamps()
      add :type, :string
    end

    create table(:resources) do
      timestamps()
      add :title, :string
      add :slug, :string
      add :last_revision_id, references(:revisions)
      add :resource_type, references(:resource_types)
      add :project_id, references(:projects)
    end

    create table(:revision_blobs) do
      timestamps()
      add :json, :string
      add :revision_id, references(:revisions)
    end

    create table(:revisions) do
      timestamps()
      add :type, :string
      add :md5, :string
      add :revision_number, :integer
      add :author_id, references(:users)
      add :previous_revision_id, references(:revisions)
    end

    # delivery
    create table(:sections) do
      timestamps()
      add :title, :string
      add :start_date, :date
      add :end_date, :date
      add :time_zone, :String
      add :institution_id, references(:institutions)
      add :open_and_free, :boolean
      add :registration_open, :boolean
    end
  end
end
