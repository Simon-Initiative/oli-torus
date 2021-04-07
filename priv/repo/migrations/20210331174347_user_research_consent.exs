defmodule Oli.Repo.Migrations.UserResearchConsent do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :research_opt_out, :boolean
    end
  end
end
