defmodule Oli.Repo.Migrations.AddReserachConsentToInstitutions do
  use Ecto.Migration
  import Ecto.Query, warn: false

  def change do
    alter table(:institutions) do
      add :research_consent, :string, default: "oli_form", null: false
    end
  end
end
