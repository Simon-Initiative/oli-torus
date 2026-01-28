defmodule Oli.Analytics.Backfill.BackfillRun do
  @moduledoc """
  Represents a ClickHouse backfill run initiated from the Torus admin console.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Accounts.Author

  @type t :: %__MODULE__{}

  @status_values [:pending, :running, :completed, :failed, :cancelled]

  @type status :: :pending | :running | :completed | :failed | :cancelled

  schema "clickhouse_backfill_runs" do
    field :target_table, :string
    field :s3_pattern, :string
    field :format, :string, default: "JSONAsString"
    field :status, Ecto.Enum, values: @status_values, default: :pending
    field :options, :map, default: %{}
    field :clickhouse_settings, :map, default: %{}
    field :dry_run, :boolean, default: false
    field :query_id, :string
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec
    field :rows_read, :integer
    field :rows_written, :integer
    field :bytes_read, :integer
    field :bytes_written, :integer
    field :duration_ms, :integer
    field :error, :string
    field :metadata, :map, default: %{}

    belongs_to :initiated_by, Author

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Returns the list of valid status values for a backfill run.
  """
  @spec status_values() :: [status()]
  def status_values, do: @status_values

  @doc """
  Base changeset for backfill runs.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :target_table,
      :s3_pattern,
      :format,
      :options,
      :clickhouse_settings,
      :dry_run,
      :query_id,
      :started_at,
      :finished_at,
      :rows_read,
      :rows_written,
      :bytes_read,
      :bytes_written,
      :duration_ms,
      :error,
      :metadata
    ])
    |> validate_required([:target_table, :s3_pattern, :format])
    |> validate_length(:target_table, max: 255)
    |> validate_length(:format, max: 255)
    |> validate_format(:target_table, ~r/^[a-zA-Z0-9_\.]+$/)
    |> validate_change(:s3_pattern, &validate_s3_pattern/2)
    |> maybe_normalize_options()
  end

  @doc """
  Changeset for system-managed updates that should not accept client input.
  """
  @spec system_changeset(t(), map()) :: Ecto.Changeset.t()
  def system_changeset(run, attrs) do
    run
    |> changeset(attrs)
    |> cast(attrs, [:status, :initiated_by_id])
  end

  @doc """
  Changeset tailored for creating a new run via the admin UI.
  """
  @spec creation_changeset(t(), map()) :: Ecto.Changeset.t()
  def creation_changeset(run, attrs) do
    run
    |> changeset(attrs)
    |> validate_required([:target_table, :s3_pattern])
  end

  defp validate_s3_pattern(:s3_pattern, nil), do: [s3_pattern: "can't be blank"]

  defp validate_s3_pattern(:s3_pattern, pattern) when is_binary(pattern) do
    trimmed = String.trim(pattern)

    cond do
      trimmed == "" ->
        [s3_pattern: "can't be blank"]

      String.starts_with?(trimmed, ["s3://", "https://", "http://"]) ->
        []

      true ->
        [s3_pattern: "must be an absolute S3 URI or HTTPS endpoint"]
    end
  end

  defp validate_s3_pattern(:s3_pattern, _other), do: [s3_pattern: "is invalid"]

  defp maybe_normalize_options(changeset) do
    changeset
    |> update_change(:options, &normalize_map/1)
    |> update_change(:clickhouse_settings, &normalize_map/1)
    |> update_change(:metadata, &normalize_map/1)
  end

  defp normalize_map(nil), do: %{}
  defp normalize_map(map) when is_map(map), do: map
  defp normalize_map(_), do: %{}
end
