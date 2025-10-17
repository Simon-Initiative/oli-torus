defmodule Oli.Analytics.Backfill.InventoryRun do
  @moduledoc """
  Represents a ClickHouse inventory backfill run driven by S3 inventory manifests.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Accounts.Author
  alias Oli.Analytics.Backfill.InventoryBatch

  @type t :: %__MODULE__{}

  @status_values [:pending, :preparing, :running, :paused, :completed, :failed, :cancelled]

  @type status ::
          :pending | :preparing | :running | :paused | :completed | :failed | :cancelled

  schema "clickhouse_inventory_runs" do
    field :inventory_date, :date
    field :inventory_prefix, :string
    field :manifest_url, :string
    field :manifest_bucket, :string
    field :target_table, :string
    field :format, :string, default: "JSONAsString"
    field :clickhouse_settings, :map, default: %{}
    field :options, :map, default: %{}
    field :status, Ecto.Enum, values: @status_values, default: :pending
    field :error, :string
    field :metadata, :map, default: %{}
    field :dry_run, :boolean, default: false
    field :total_batches, :integer, default: 0
    field :completed_batches, :integer, default: 0
    field :failed_batches, :integer, default: 0
    field :running_batches, :integer, default: 0
    field :pending_batches, :integer, default: 0
    field :rows_ingested, :integer
    field :bytes_ingested, :integer
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec

    belongs_to :initiated_by, Author
    has_many :batches, InventoryBatch, foreign_key: :run_id

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  List of possible run statuses.
  """
  @spec status_values() :: [status()]
  def status_values, do: @status_values

  @doc """
  Base changeset for inventory backfill runs.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :inventory_date,
      :inventory_prefix,
      :manifest_url,
      :manifest_bucket,
      :target_table,
      :format,
      :clickhouse_settings,
      :options,
      :status,
      :error,
      :metadata,
      :dry_run,
      :total_batches,
      :completed_batches,
      :failed_batches,
      :running_batches,
      :pending_batches,
      :rows_ingested,
      :bytes_ingested,
      :started_at,
      :finished_at,
      :initiated_by_id
    ])
    |> validate_required([
      :inventory_date,
      :inventory_prefix,
      :manifest_url,
      :manifest_bucket,
      :target_table,
      :format,
      :status
    ])
    |> validate_length(:target_table, max: 255)
    |> validate_format(:target_table, ~r/^[a-zA-Z0-9_\.]+$/)
    |> maybe_normalize_maps()
    |> maybe_normalize_counts()
  end

  @doc """
  Changeset tailored for newly scheduled runs.
  """
  @spec creation_changeset(t(), map()) :: Ecto.Changeset.t()
  def creation_changeset(run, attrs) do
    run
    |> changeset(attrs)
    |> validate_required([:inventory_date, :manifest_url, :manifest_bucket])
  end

  defp maybe_normalize_maps(changeset) do
    changeset
    |> update_change(:metadata, &normalize_map/1)
    |> update_change(:clickhouse_settings, &normalize_map/1)
    |> update_change(:options, &normalize_map/1)
  end

  defp maybe_normalize_counts(changeset) do
    Enum.reduce(
      [:total_batches, :completed_batches, :failed_batches, :running_batches, :pending_batches],
      changeset,
      fn field, cs ->
        update_change(cs, field, fn
          nil ->
            0

          value when is_integer(value) and value >= 0 ->
            value

          value when is_binary(value) ->
            case Integer.parse(value) do
              {int, _} when int >= 0 -> int
              _ -> 0
            end

          _ ->
            0
        end)
      end
    )
  end

  defp normalize_map(nil), do: %{}
  defp normalize_map(map) when is_map(map), do: map
  defp normalize_map(_), do: %{}
end
