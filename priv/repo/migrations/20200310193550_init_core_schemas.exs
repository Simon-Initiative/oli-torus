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
      add :project_id, references(:projects)
      add :family_id, references(:families)

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
