defmodule Oli.Repo.Migrations.DisableAssistantInExistingSections do
  use Ecto.Migration

  def change do
    execute "UPDATE sections SET assistant_enabled = false"

    flush()

    alter table("sections") do
      modify :assistant_enabled, :boolean, default: false, null: false
    end
  end
end
