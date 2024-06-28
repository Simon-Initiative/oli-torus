defmodule Oli.Repo.Migrations.RevisionIdsAdded do
  use Ecto.Migration

  def change do
    # track ids at the revision level instead of the publication level
    alter table(:revisions) do
      add :ids_added, :boolean, default: false
    end

    alter table(:publications) do
      remove :ids_added, :boolean, default: false
    end
  end
end
