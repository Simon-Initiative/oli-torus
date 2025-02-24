defmodule Oli.Repo.Migrations.TriggersEnabled do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add :triggers_enabled, :boolean, default: false
    end
  end
end
