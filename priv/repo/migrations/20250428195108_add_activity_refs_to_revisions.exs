defmodule Oli.Repo.Migrations.AddActivityRefsToRevisions do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :activity_refs, {:array, :id}, default: [], null: false
    end
  end
end
