defmodule Oli.Repo.Migrations.CreateClickhouseInventoryTables do
  use Ecto.Migration

  def change do
    create table(:clickhouse_inventory_runs) do
      add :dry_run, :boolean, null: false, default: false
      add :inventory_date, :date, null: false
      add :inventory_prefix, :string, null: false
      add :manifest_url, :text, null: false
      add :manifest_bucket, :string, null: false
      add :target_table, :string, null: false
      add :format, :string, null: false, default: "JSONAsString"
      add :clickhouse_settings, :map, null: false, default: %{}
      add :options, :map, null: false, default: %{}
      add :status, :string, null: false, default: "pending"
      add :error, :text
      add :metadata, :map, null: false, default: %{}
      add :total_batches, :integer, null: false, default: 0
      add :completed_batches, :integer, null: false, default: 0
      add :failed_batches, :integer, null: false, default: 0
      add :running_batches, :integer, null: false, default: 0
      add :pending_batches, :integer, null: false, default: 0
      add :rows_ingested, :bigint
      add :bytes_ingested, :bigint
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec
      add :initiated_by_id, references(:authors, on_delete: :nothing)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:clickhouse_inventory_runs, [:status])
    create index(:clickhouse_inventory_runs, [:inventory_date])

    create table(:clickhouse_inventory_batches) do
      add :run_id, references(:clickhouse_inventory_runs, on_delete: :delete_all), null: false
      add :sequence, :integer, null: false
      add :parquet_key, :text, null: false
      add :object_count, :integer
      add :processed_objects, :integer, null: false, default: 0
      add :status, :string, null: false, default: "pending"
      add :error, :text
      add :metadata, :map, null: false, default: %{}
      add :rows_ingested, :bigint
      add :bytes_ingested, :bigint
      add :attempts, :integer, null: false, default: 0
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec
      add :last_attempt_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:clickhouse_inventory_batches, [:run_id])
    create index(:clickhouse_inventory_batches, [:status])
    create unique_index(:clickhouse_inventory_batches, [:run_id, :sequence])
  end
end
