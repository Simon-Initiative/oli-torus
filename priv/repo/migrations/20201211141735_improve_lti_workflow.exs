defmodule Oli.Repo.Migrations.UnlinkInstitutionAuthor do
  use Ecto.Migration

  def change do
    alter table(:institutions) do
      remove :author_id, references(:authors)
      add :approved_at, :utc_datetime
    end

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
