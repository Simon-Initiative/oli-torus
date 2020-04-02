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

    create table(:nonce_store) do
      add :value, :string

      timestamps()
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

      timestamps()
    end

    create table(:families) do
      add :title, :string
      add :slug, :string
      add :description, :string

      timestamps()
    end

    create table(:projects) do
      add :title, :string
      add :slug, :string
      add :description, :string
      add :version, :string
      add :project_id, references(:projects)
      add :family_id, references(:families)

      timestamps()
    end

    create table(:publications) do
      add :description, :string
      add :root_resources, {:array, :id}
      add :published, :boolean, default: false, null: false
      add :open_and_free, :boolean, default: false, null: false
      add :project_id, references(:projects)
      timestamps()
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

      timestamps()
    end

    create table(:resource_families) do
      timestamps()
    end


    create table(:resources) do
      add :family_id, references(:resource_families)
      add :project_id, references(:projects)
      timestamps()
    end

    create table(:resource_revisions) do
      add :title, :string
      add :slug, :string
      add :content, {:array, :map}
      add :children, {:array, :id}
      add :objectives, {:array, :id}
      add :deleted, :boolean, default: false, null: false
      add :author_id, references(:authors)
      add :resource_id, references(:resources)
      add :resource_type_id, references(:resource_types)
      add :previous_revision_id, references(:resource_revisions)

      timestamps()
    end

    create table(:activity_registrations) do
      add :title, :string
      add :icon, :string
      add :description, :string
      add :element_name, :string
      add :delivery_script, :string
      add :authoring_script, :string

      timestamps()
    end

    create table(:activities) do
      add :slug, :string
      add :project_id, references(:projects)
      timestamps()
    end

    create table(:activity_revisions) do
      add :content, :map
      add :objectives, {:array, :id}
      add :slug, :string
      add :deleted, :boolean, default: false, null: false

      add :author_id, references(:authors)
      add :activity_id, references(:activities)
      add :activity_type_id, references(:activity_registrations)
      add :previous_revision_id, references(:activity_revisions)

      timestamps()
    end

    create table(:objectives) do
      add :slug, :string
      add :project_id, references(:projects)

      timestamps()
    end

    create table(:objective_revisions) do
      add :title, :string
      add :children, {:array, :id}
      add :deleted, :boolean, default: false, null: false

      add :objective_id, references(:objectives)
      add :previous_revision_id, references(:objective_revisions)

      timestamps()
    end

    create table(:resource_mappings) do
      add :resource_id, references(:resources)
      add :publication_id, references(:publications)
      add :revision_id, references(:resource_revisions)
      timestamps()
    end

    create table(:activity_mappings) do
      add :activity_id, references(:activities)
      add :publication_id, references(:publications)
      add :revision_id, references(:activity_revisions)
      timestamps()
    end

    create table(:objective_mappings) do
      add :objective_id, references(:objectives)
      add :publication_id, references(:publications)
      add :revision_id, references(:objective_revisions)
      timestamps()
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

  end
end
