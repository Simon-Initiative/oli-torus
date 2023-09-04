defmodule Oli.Repo.Migrations.AddStartDateToDeliverySettings do
  use Ecto.Migration

  def change do
    alter table(:delivery_settings) do
      add :start_date, :utc_datetime, null: true
    end
  end
end
