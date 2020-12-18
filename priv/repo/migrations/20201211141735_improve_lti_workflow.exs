defmodule Oli.Repo.Migrations.UnlinkInstitutionAuthor do
  use Ecto.Migration

  def change do
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
    end

    create unique_index(:pending_registrations, [:issuer, :client_id])

    alter table(:lti_1p3_deployments) do
      remove :registration_id, references(:lti_1p3_registrations)
    end

    alter table(:lti_1p3_registrations) do
      remove :institution_id, references(:institutions)
    end

    flush()

    alter table(:lti_1p3_deployments) do
      add :registration_id, references(:lti_1p3_registrations, on_delete: :delete_all)
    end

    alter table(:lti_1p3_registrations) do
      add :institution_id, references(:institutions, on_delete: :delete_all)
    end
  end
end
