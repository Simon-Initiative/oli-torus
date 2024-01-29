defmodule Oli.Repo.Migrations.AddSectionAssistantEnable do
  use Ecto.Migration

  def up do
    alter table(:sections) do
      add :assistant_enabled, :boolean, default: true
    end
  end

  def down do
    alter table(:sections) do
      remove :assistant_enabled, :boolean, default: true
    end
  end
end
