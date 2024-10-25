defmodule Oli.Repo.Migrations.DropSnapshots do
  use Ecto.Migration

  def change do
    drop table(:snapshots)
  end
end
