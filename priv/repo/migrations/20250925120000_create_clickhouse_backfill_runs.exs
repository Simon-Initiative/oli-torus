defmodule Oli.Repo.Migrations.CreateClickhouseBackfillRuns do
  use Ecto.Migration

  def change do
    create table(:clickhouse_backfill_runs) do
      add :target_table, :string, null: false
      add :s3_pattern, :text, null: false
      add :format, :string, null: false, default: "JSONAsString"
      add :status, :string, null: false, default: "pending"
      add :options, :map, null: false, default: %{}
      add :clickhouse_settings, :map, null: false, default: %{}
      add :dry_run, :boolean, null: false, default: false
      add :query_id, :string
      add :initiated_by_id, references(:authors, on_delete: :nothing)
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec
      add :rows_read, :bigint
      add :rows_written, :bigint
      add :bytes_read, :bigint
      add :bytes_written, :bigint
      add :duration_ms, :bigint
      add :error, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create index(:clickhouse_backfill_runs, [:status])
    create index(:clickhouse_backfill_runs, [:initiated_by_id])
    create unique_index(:clickhouse_backfill_runs, [:query_id], where: "query_id IS NOT NULL")
  end
end
