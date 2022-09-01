defmodule Oli.Repo.Migrations.AddParameters do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :parameters, :map
    end
  end
end
