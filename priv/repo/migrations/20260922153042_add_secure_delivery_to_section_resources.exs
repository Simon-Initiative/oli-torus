defmodule Oli.Repo.Migrations.AddSecureDeliveryToSectionResources do
  use Ecto.Migration

  def up do
    alter table(:section_resources) do
      add :secure_delivery, :boolean, null: false, default: false
    end
  end

  def down do
    alter table(:section_resources) do
      remove :secure_delivery
    end
  end
end
