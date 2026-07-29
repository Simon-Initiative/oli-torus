defmodule Oli.Repo.Migrations.AddAuthoringFeatureSettingsToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :experiments_enabled, :boolean, null: false, default: false
      add :alternatives_enabled, :boolean, null: false, default: false
    end
  end
end
