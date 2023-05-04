defmodule Oli.Repo.Migrations.UpdateRevisionsAddPurpose do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :purpose, :string, default: "foundation", null: false
      add :relates_to, {:array, :id}, default: [], null: false
    end
  end
end
