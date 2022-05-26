defmodule Oli.Repo.Migrations.AutomationSetupScope do
  use Ecto.Migration

  def change do
    alter table(:api_keys) do
      add :automation_setup_enabled, :boolean, default: false, null: false
    end
  end
end
