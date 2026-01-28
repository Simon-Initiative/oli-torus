defmodule Oli.Repo.Migrations.CreateClickhouseInventoryChunkLogs do
  use Ecto.Migration

  def change do
    create table(:clickhouse_inventory_chunk_logs) do
      add :batch_id, references(:clickhouse_inventory_batches, on_delete: :delete_all),
        null: false

      add :chunk_index, :string, null: false
      add :metrics, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:clickhouse_inventory_chunk_logs, [:batch_id])
    create unique_index(:clickhouse_inventory_chunk_logs, [:batch_id, :chunk_index])
  end
end
