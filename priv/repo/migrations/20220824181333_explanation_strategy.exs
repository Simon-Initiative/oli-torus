defmodule Oli.Repo.Migrations.ExplanationStrategy do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :explanation_strategy, :map
    end
  end
end
