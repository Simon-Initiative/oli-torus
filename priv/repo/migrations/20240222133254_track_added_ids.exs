defmodule Oli.Repo.Migrations.TrackAddedIds do
  use Ecto.Migration

  def up do
    alter table(:publications) do
      add :ids_added, :boolean, default: false
    end
  end

  def down do
    alter table(:publications) do
      remove :ids_added, :boolean, default: false
    end
  end
end
