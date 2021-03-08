defmodule Oli.Repo.Migrations.AllowClientEvaluation do
  use Ecto.Migration

  def change do
    alter table(:activity_registrations) do
      add :allow_client_evaluation, :boolean
    end
  end
end
