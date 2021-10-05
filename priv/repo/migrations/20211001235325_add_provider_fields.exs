defmodule Oli.Repo.Migrations.AddProviderFields do
  use Ecto.Migration

  def change do
    alter table(:payments) do
      add :provider_type, :string, default: "stripe", null: true
      add :provider_id, :string
      add :provider_payload, :map, default: %{}
      add :pending_user_id, :integer
      add :pending_section_id, :integer
    end

    create unique_index(:payments, [:provider_type, :provider_id])
    create index(:payments, [:provider_id])
  end
end
