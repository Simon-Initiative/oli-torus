defmodule Oli.Repo.Migrations.CreateResearchConsent do
  use Ecto.Migration

  import Ecto.Query, warn: false

  alias Oli.Repo

  def up do
    create table(:research_consent) do
      add :research_consent, :string, default: "oli_form", null: false
    end

    flush()

    Repo.insert_all(
      "research_consent",
      [%{research_consent: "oli_form"}]
    )
  end

  def down do
    drop table(:research_consent)
  end
end
