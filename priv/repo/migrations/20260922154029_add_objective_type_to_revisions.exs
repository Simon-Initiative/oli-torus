defmodule Oli.Repo.Migrations.AddObjectiveTypeToRevisions do
  use Ecto.Migration

  def up do
    alter table(:revisions) do
      add :objective_type, :string, null: false, default: "objective"
    end
  end

  def down do
    alter table(:revisions) do
      remove :objective_type
    end
  end
end
