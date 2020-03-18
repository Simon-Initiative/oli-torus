defmodule Oli.Repo.Migrations.InitCoreSchemas do
  use Ecto.Migration

  def change do
    create table(:resource_types) do
      timestamps()
      add :type, :string
    end

    create table(:system_roles) do
      timestamps()
      add :type, :string
    end

    create unique_index(:system_roles, [:type])

    create table(:project_roles) do
      timestamps()
      add :type, :string
    end

    create table(:section_roles) do
      timestamps()
      add :type, :string
    end

    create table(:authors) do
      add :email, :string
      add :first_name, :string
      add :last_name, :string
      add :provider, :string
      add :token, :string
      add :password_hash, :string
      add :email_verified, :boolean
      add :system_role_id, references(:system_roles)

      timestamps()
    end

    create unique_index(:authors, [:email])

    create table(:institutions) do
      add :institution_email, :string
      add :name, :string
      add :country_code, :string
      add :institution_url, :string
      add :timezone, :string
      add :consumer_key, :string
      add :shared_secret, :string
      add :author_id, references(:authors)

      timestamps()
    end

    create table(:lti_tool_consumers) do
      add :instance_guid, :string
      add :instance_name, :string
      add :instance_contact_email, :string
      add :info_version, :string
      add :info_product_family_code, :string
      add :institution_id, references(:institutions)

      timestamps()
    end

    create table(:user) do
      add :email, :string
      add :first_name, :string
      add :last_name, :string
      add :user_id, :string
      add :user_image, :string
      add :roles, :string
      add :author_id, references(:authors)
      add :lti_tool_consumer_id, references(:lti_tool_consumers)
      add :institution_id, references(:institutions)

      timestamps()
    end

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

    create table(:sections) do
      timestamps()
      add :title, :string
      add :start_date, :date
      add :end_date, :date
      add :time_zone, :string
      add :institution_id, references(:institutions)
      add :open_and_free, :boolean
      add :registration_open, :boolean
    end

    create table(:authors_sections) do
      timestamps()
      add :author_id, references(:authors)
      add :section_id, references(:sections)
      add :section_role_id, references(:section_roles)
    end

    create table(:authors_projects) do
      timestamps()
      add :author_id, references(:authors)
      add :project_id, references(:projects)
      add :project_role_id, references(:project_roles)
    end

    create table(:revisions) do
      timestamps()
      add :type, :string
      add :md5, :string
      add :revision_number, :integer
      add :author_id, references(:authors)
      add :previous_revision_id, references(:revisions)
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
      add :content, :map
      add :revision_id, references(:revisions)
    end

    create table(:pages_with_position) do
      timestamps()
      add :project_id, references(:projects)
      add :page_id, references(:resources)
      add :position, :integer
    end

    create table(:objectives) do
      timestamps()
      add :description, :string
      add :project_id, references(:projects)
    end

    create table(:objectives_objectives) do
      timestamps()
      add :parent_id, references(:objectives)
      add :child_id, references(:objectives)
    end
  end
end
