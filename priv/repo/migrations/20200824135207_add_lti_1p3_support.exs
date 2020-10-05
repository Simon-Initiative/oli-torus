defmodule Oli.Repo.Migrations.AddLti13RegistrationTable do
  use Ecto.Migration

  # def up do
  #   alter table(:enrollments) do
  #     # modify :user_id, references(:users), primary_key: false
  #     # modify :section_id, references(:sections), primary_key: false

  #     # flush()
  #     drop(constraint(:enrollments, :index_user_section))
  #     create index(:enrollments, [:user_id, :section_id])
  #     # create unique_index(:enrollments, [:user_id, :section_id], name: :index_user_section)

  #     modify :id, :integer, primary_key: true
  #   end
  # end

  # def down do
  #   alter table(:enrollments) do
  #     modify :id, :integer, primary_key: false

  #     flush()

  #     modify :user_id, references(:users), primary_key: true
  #     modify :section_id, references(:sections), primary_key: true
  #   end
  # end

  def change do
    drop(constraint(:enrollments, "enrollments_pkey"))

    alter table(:enrollments) do
      modify :id, :integer, primary_key: true
    end

    create table(:lti_1p3_jwks) do
      add :pem, :text
      add :typ, :string
      add :alg, :string
      add :kid, :string
      add :active, :boolean, default: false, null: false

      timestamps(type: :timestamptz)
    end

    create table(:lti_1p3_registrations) do
      add :issuer, :string
      add :client_id, :string
      add :key_set_url, :string
      add :auth_token_url, :string
      add :auth_login_url, :string
      add :auth_server, :string
      add :kid, :string

      add :tool_jwk_id, references(:lti_1p3_jwks)
      add :institution_id, references(:institutions)

      timestamps(type: :timestamptz)
    end

    create table(:lti_1p3_deployments) do
      add :deployment_id, :string
      add :registration_id, references(:lti_1p3_registrations)

      timestamps(type: :timestamptz)
    end

    create table(:lti_1p3_platform_roles) do
      add :uri, :string
    end

    create unique_index(:lti_1p3_platform_roles, [:uri])

    create table(:lti_1p3_context_roles) do
      add :uri, :string
    end

    create unique_index(:lti_1p3_context_roles, [:uri])

    create table(:lti_1p3_params) do
      add :key, :string
      add :data, :map
      add :exp, :utc_datetime

      timestamps(type: :timestamptz)
    end

    create unique_index(:lti_1p3_params, [:key])

    create table(:users_platform_roles, primary_key: false) do
      add :user_id, references(:users)
      add :platform_role_id, references(:lti_1p3_platform_roles)
    end

    create table(:enrollments_context_roles, primary_key: false) do
      add :enrollment_id, references(:enrollments)
      add :context_role_id, references(:lti_1p3_context_roles)
    end

    alter table(:sections) do
      remove :lti_lineitems_url, :string
      remove :lti_lineitems_token, :string
      remove :canvas_url, :string
      remove :canvas_token, :string
      remove :canvas_id, :string

      add :lti_1p3_deployment_id, references(:lti_1p3_deployments)
    end

    alter table(:institutions) do
      remove :consumer_key, :string
      remove :shared_secret, :string
    end

    alter table(:users) do
      remove :roles, :string
      remove :canvas_id, :string
      remove :lti_tool_consumer_id, references(:lti_tool_consumers)
    end

    alter table(:enrollments) do
      remove :section_role_id, references(:section_roles)
    end

    alter table(:authors_sections) do
      remove :section_role_id, references(:section_roles)
    end

    drop table(:section_roles)
    drop table(:lti_tool_consumers)

  end
end
