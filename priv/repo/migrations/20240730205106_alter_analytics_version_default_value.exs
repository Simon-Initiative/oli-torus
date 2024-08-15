defmodule Oli.Repo.Migrations.AlterAnalyticsVersionDefaultValue do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      modify :analytics_version, :string, default: "v2"
    end

    alter table(:projects) do
      modify :analytics_version, :string, default: "v2"
    end
  end
end
