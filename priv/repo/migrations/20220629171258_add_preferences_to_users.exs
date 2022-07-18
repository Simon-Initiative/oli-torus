defmodule Oli.Repo.Migrations.AddPreferencesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :preferences, :map
    end
  end
end
