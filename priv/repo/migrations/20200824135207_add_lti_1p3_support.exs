defmodule Oli.Repo.Migrations.AddLti13RegistrationTable do
  use Ecto.Migration

  def change do
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

      add :platform_roles, {:array, :jsonb}, default: []
    end

    alter table(:enrollments) do
      remove :section_role_id, references(:section_roles)

      add :context_roles, {:array, :jsonb}, default: []
    end

    alter table(:authors_sections) do
      remove :section_role_id, references(:section_roles)
    end

    drop table(:section_roles)
    drop table(:lti_tool_consumers)
    drop table(:nonces)

  end
end
