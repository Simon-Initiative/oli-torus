defmodule Oli.Repo.Migrations.ProjectDatashopSnapshot do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add(:latest_datashop_snapshot_url, :string)
      add(:latest_datashop_snapshot_timestamp, :utc_datetime)
    end
  end
end
