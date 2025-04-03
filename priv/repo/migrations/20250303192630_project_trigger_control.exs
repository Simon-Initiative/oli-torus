defmodule Oli.Repo.Migrations.ProjectTriggerControl do
  use Ecto.Migration

  def up do
    alter table(:projects) do
      add :allow_triggers, :boolean, default: false
    end
  end

  def down do
    alter table(:projects) do
      remove :allow_triggers
    end
  end
end
