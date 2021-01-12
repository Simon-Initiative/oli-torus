defmodule Oli.Repo.Migrations.ImproveLtiWorkflow do
  use Ecto.Migration

  def up do
    alter table(:institutions) do
      remove :author_id, references(:authors)
    end

    create table(:pending_registrations) do
      add :country_code, :string
      add :institution_email, :string
      add :institution_url, :string
      add :name, :string
      add :timezone, :string

      add :issuer, :string
      add :client_id, :string
      add :key_set_url, :string
      add :auth_token_url, :string
      add :auth_login_url, :string
      add :auth_server, :string

      timestamps()
    end

    create unique_index(:pending_registrations, [:issuer, :client_id])

    drop(constraint(:lti_1p3_registrations, "lti_1p3_registrations_institution_id_fkey"))

    alter table(:lti_1p3_registrations) do
      modify(:institution_id, references(:institutions, on_delete: :delete_all), null: false)
    end

    drop(constraint(:lti_1p3_deployments, "lti_1p3_deployments_registration_id_fkey"))

    alter table(:lti_1p3_deployments) do
      modify(:registration_id, references(:lti_1p3_registrations, on_delete: :delete_all), null: false)
    end
  end

  def down do
    drop(constraint(:lti_1p3_deployments, "lti_1p3_deployments_registration_id_fkey"))

    alter table(:lti_1p3_deployments) do
      modify(:registration_id, references(:lti_1p3_registrations, on_delete: :nothing), null: false)
    end

    drop(constraint(:lti_1p3_registrations, "lti_1p3_registrations_institution_id_fkey"))

    alter table(:lti_1p3_registrations) do
      modify(:institution_id, references(:institutions, on_delete: :nothing), null: false)
    end

    drop unique_index(:pending_registrations, [:issuer, :client_id])

    drop table(:pending_registrations)

    alter table(:institutions) do
      add :author_id, references(:authors)
    end
  end
end
