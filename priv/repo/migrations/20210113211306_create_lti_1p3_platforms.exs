defmodule Oli.Repo.Migrations.CreateLti1p3Platforms do
  use Ecto.Migration

  def change do
    create table(:lti_1p3_platform_instances) do
      add :name, :string
      add :description, :text
      add :target_link_uri, :string
      add :client_id, :string
      add :login_url, :string
      add :keyset_url, :string
      add :redirect_uris, :text
      add :custom_params, :text

      timestamps(type: :timestamptz)
    end

    create unique_index(:lti_1p3_platform_instances, :client_id)

    alter table(:nonces) do
      add :domain, :string
    end

    drop unique_index(:nonces, [:value])
    create unique_index(:nonces, [:value, :domain], name: :value_domain_index)

    create table(:lti_1p3_login_hints) do
      add :value, :string
      add :session_user_id, :integer
      add :context, :string

      timestamps(type: :timestamptz)
    end

    create unique_index(:lti_1p3_login_hints, :value)

  end
end
