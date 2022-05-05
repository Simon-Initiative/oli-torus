defmodule Oli.Repo.Migrations.AutomationSetupScope do
  use Ecto.Migration

  def change do
    alter table(:api_keys) do
      add :automation_setup_enabled, :boolean, default: false, null: false
    end

    flush()

    execute "UPDATE api_keys SET automation_setup_enabled = false;"
  end
end
