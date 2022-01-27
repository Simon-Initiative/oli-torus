defmodule Oli.Repo.Migrations.RefactorLtiParams do
  use Ecto.Migration

  def up do
    alter table(:lti_1p3_params) do
      remove :key, :string

      add :issuer, :string
      add :client_id, :string
      add :deployment_id, :string
      add :context_id, :string
      add :sub, :string

      add :user_id, references(:users)
    end

    create unique_index(:lti_1p3_params, [
             :issuer,
             :client_id,
             :deployment_id,
             :context_id,
             :sub
           ])
  end
end
