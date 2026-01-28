defmodule Oli.Analytics.Backfill.InventoryBatch do
  @moduledoc """
  Represents the processing state for a single parquet-described batch within an inventory run.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Analytics.Backfill.InventoryRun

  @type t :: %__MODULE__{}

  @status_values [:pending, :queued, :running, :paused, :completed, :failed, :cancelled]

  @type status ::
          :pending | :queued | :running | :paused | :completed | :failed | :cancelled

  schema "clickhouse_inventory_batches" do
    field :sequence, :integer
    field :parquet_key, :string
    field :object_count, :integer
    field :processed_objects, :integer, default: 0
    field :status, Ecto.Enum, values: @status_values, default: :pending
    field :error, :string
    field :metadata, :map, default: %{}
    field :rows_ingested, :integer
    field :bytes_ingested, :integer
    field :attempts, :integer, default: 0
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec
    field :last_attempt_at, :utc_datetime_usec

    belongs_to :run, InventoryRun

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  List of valid batch statuses.
  """
  @spec status_values() :: [status()]
  def status_values, do: @status_values

  @doc """
  Base changeset for inventory batches.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(batch, attrs) do
    batch
    |> cast(attrs, [
      :sequence,
      :parquet_key,
      :object_count,
      :processed_objects,
      :status,
      :error,
      :metadata,
      :rows_ingested,
      :bytes_ingested,
      :attempts,
      :started_at,
      :finished_at,
      :last_attempt_at,
      :run_id
    ])
    |> validate_required([:sequence, :parquet_key, :status, :run_id])
    |> validate_number(:sequence, greater_than_or_equal_to: 0)
    |> validate_number(:object_count, greater_than_or_equal_to: 0)
    |> validate_number(:processed_objects, greater_than_or_equal_to: 0)
    |> maybe_normalize_map(:metadata)
  end

  @doc """
  Changeset for newly prepared batches.
  """
  @spec creation_changeset(t(), map()) :: Ecto.Changeset.t()
  def creation_changeset(batch, attrs) do
    batch
    |> changeset(attrs)
    |> validate_required([:sequence, :parquet_key])
  end

  defp maybe_normalize_map(changeset, field) do
    update_change(changeset, field, fn
      nil -> %{}
      map when is_map(map) -> map
      _ -> %{}
    end)
  end
end
