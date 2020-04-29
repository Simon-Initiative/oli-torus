defmodule Oli.Repo.Migrations.InitCoreSchemas do
  use Ecto.Migration

  def change do
    create table(:resource_types) do
      timestamps(type: :timestamptz)
      add :type, :string
    end

    create table(:system_roles) do
      timestamps(type: :timestamptz)
      add :type, :string
    end

    create unique_index(:system_roles, [:type])

    create table(:project_roles) do
      timestamps(type: :timestamptz)
      add :type, :string
    end

    create table(:section_roles) do
      timestamps(type: :timestamptz)
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

      timestamps(type: :timestamptz)
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

      timestamps(type: :timestamptz)
    end

    create table(:lti_tool_consumers) do
      add :instance_guid, :string
      add :instance_name, :string
      add :instance_contact_email, :string
      add :info_version, :string
      add :info_product_family_code, :string
      add :institution_id, references(:institutions)

      timestamps(type: :timestamptz)
    end

    create table(:nonce_store) do
      add :value, :string

      timestamps(type: :timestamptz)
    end

    create unique_index(:nonce_store, [:value])

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

      timestamps(type: :timestamptz)
    end

    create table(:families) do
      add :title, :string
      add :slug, :string
      add :description, :string

      timestamps(type: :timestamptz)
    end

    create table(:projects) do
      add :title, :string
      add :slug, :string
      add :description, :string
      add :version, :string
      add :project_id, references(:projects)
      add :family_id, references(:families)

      timestamps(type: :timestamptz)
    end

    create table(:resources) do
      timestamps(type: :timestamptz)
    end

    create table(:publications) do
      add :description, :string
      add :published, :boolean, default: false, null: false
      add :open_and_free, :boolean, default: false, null: false
      add :root_resource_id, references(:resources)
      add :project_id, references(:projects)
      timestamps(type: :timestamptz)
    end

    create table(:sections) do
      add :title, :string
      add :start_date, :date
      add :end_date, :date
      add :time_zone, :string
      add :open_and_free, :boolean, default: false, null: false
      add :registration_open, :boolean, default: false, null: false
      add :context_id, :string

      add :institution_id, references(:institutions)
      add :project_id, references(:projects)
      add :publication_id, references(:publications)

      timestamps(type: :timestamptz)
    end

    create table(:activity_registrations) do
      add :slug, :string
      add :title, :string
      add :icon, :string
      add :description, :string
      add :delivery_element, :string
      add :authoring_element, :string
      add :delivery_script, :string
      add :authoring_script, :string

      timestamps(type: :timestamptz)
    end
    create unique_index(:activity_registrations, [:slug], name: :index_slug_registrations)
    create unique_index(:activity_registrations, [:delivery_element], name: :index_delivery_element_registrations)
    create unique_index(:activity_registrations, [:authoring_element], name: :index_authoring_element_registrations)
    create unique_index(:activity_registrations, [:delivery_script], name: :index_delivery_script_registrations)
    create unique_index(:activity_registrations, [:authoring_script], name: :index_authoring_script_registrations)


    create table(:revisions) do
      add :title, :string
      add :slug, :string
      add :content, :map
      add :children, {:array, :id}
      add :objectives, :map
      add :deleted, :boolean, default: false, null: false
      add :graded, :boolean, default: false, null: false
      add :author_id, references(:authors)
      add :resource_id, references(:resources)
      add :resource_type_id, references(:resource_types)
      add :previous_revision_id, references(:revisions)
      add :activity_type_id, references(:activity_registrations)

      timestamps(type: :timestamptz)
    end
    create index(:revisions, [:slug], name: :index_slug_revisions)

    create table(:published_resources) do
      add :resource_id, references(:resources)
      add :publication_id, references(:publications)
      add :revision_id, references(:revisions)
      add :locked_by_id, references(:authors), null: true
      add :lock_updated_at, :naive_datetime
      timestamps(type: :timestamptz)
    end

    create table(:enrollments) do
      timestamps()
      add :user_id, references(:user), primary_key: true
      add :section_id, references(:sections), primary_key: true
      add :section_role_id, references(:section_roles)
    end

    create index(:enrollments, [:user_id])
    create index(:enrollments, [:section_id])
    create unique_index(:enrollments, [:user_id, :section_id], name: :index_user_section)


    create table(:authors_sections) do
      timestamps(type: :timestamptz)
      add :author_id, references(:authors), primary_key: true
      add :section_id, references(:sections), primary_key: true
      add :section_role_id, references(:section_roles)
    end

    create index(:authors_sections, [:author_id])
    create index(:authors_sections, [:section_id])
    create unique_index(:authors_sections, [:author_id, :section_id], name: :index_author_section)

    create table(:authors_projects, primary_key: false) do
      timestamps(type: :timestamptz)
      add :author_id, references(:authors), primary_key: true
      add :project_id, references(:projects), primary_key: true
      add :project_role_id, references(:project_roles)
    end

    create index(:authors_projects, [:author_id])
    create index(:authors_projects, [:project_id])
    create unique_index(:authors_projects, [:author_id, :project_id], name: :index_author_project)


    create table(:projects_resources, primary_key: false) do
      timestamps(type: :timestamptz)
      add :project_id, references(:projects), primary_key: true
      add :resource_id, references(:resources), primary_key: true
    end

    create index(:projects_resources, [:resource_id])
    create index(:projects_resources, [:project_id])
    create unique_index(:projects_resources, [:resource_id, :project_id], name: :index_project_resource)
  end
end
