defmodule Oli.Repo.Migrations.AddDeliverySettings do
  use Ecto.Migration

  def change do
    create table(:delivery_settings) do
      add :user_id, references(:users)
      add :section_id, references(:sections)
      add :resource_id, references(:resources)

      add :collab_space_config, :map

      timestamps(type: :timestamptz)
    end

    create index(:delivery_settings, [:section_id, :resource_id])
    create index(:delivery_settings, [:user_id])
  end
end
