defmodule Oli.Analytics.Backfill.InventoryChunkLog do
  @moduledoc """
  Represents a persisted chunk log entry for an inventory batch.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Analytics.Backfill.InventoryBatch

  @type t :: %__MODULE__{}

  schema "clickhouse_inventory_chunk_logs" do
    field :chunk_index, :string
    field :metrics, :map, default: %{}

    belongs_to :batch, InventoryBatch

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for chunk log entries.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:chunk_index, :metrics, :batch_id])
    |> validate_required([:chunk_index, :metrics, :batch_id])
    |> validate_length(:chunk_index, min: 1)
  end
end
