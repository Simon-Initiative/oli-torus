defmodule Oli.Repo.Migrations.AddInstitutionToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :lti_institution_id, :integer, default: nil
    end

    create unique_index(:users, [:sub, :lti_institution_id])
  end
end
