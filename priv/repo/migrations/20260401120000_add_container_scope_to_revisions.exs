defmodule Oli.Repo.Migrations.AddContainerScopeToRevisions do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :container_scope, :string, default: "project", null: false
    end
  end
end
