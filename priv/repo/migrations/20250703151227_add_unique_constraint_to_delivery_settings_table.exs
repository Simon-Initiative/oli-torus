defmodule Oli.Repo.Migrations.AddUniqueConstraintToDeliverySettingsTable do
  use Ecto.Migration

  def change do
    create unique_index(:delivery_settings, [:section_id, :resource_id, :user_id])
  end
end
