defmodule Oli.Repo.Migrations.ProjectAnalyticsSnapshot do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :latest_analytics_snapshot_url, :string
      add :latest_analytics_snapshot_timestamp, :utc_datetime
    end
  end
end
