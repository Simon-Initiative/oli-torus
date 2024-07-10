defmodule Oli.Repo.Migrations.AsyncProjectExport do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :latest_export_url, :string
      add :latest_export_timestamp, :utc_datetime
    end
  end
end
