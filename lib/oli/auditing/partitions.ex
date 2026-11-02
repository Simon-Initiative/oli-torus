defmodule Oli.Auditing.Partitions do
  @moduledoc """
  Half-year partitions of `audit_log_events`.

  `audit_log_events_y<YYYY>h1` covers `[YYYY-01-01, YYYY-07-01)` and `audit_log_events_y<YYYY>h2`
  covers `[YYYY-07-01, (YYYY+1)-01-01)`, in UTC. There is no default partition: a row outside
  every partition fails to insert. `Oli.Auditing.PartitionMaintenanceWorker` keeps four future
  half-years provisioned.

  Partition names are built only from `Date` values by `name_for/1`; request input never reaches
  an identifier. Nothing here deletes partitions on a schedule; `detach/1` exists for
  rehearsals and operators.
  """

  require Logger

  alias Oli.Auditing.Error
  alias Oli.Repo

  @table "audit_log_events"
  @name_pattern ~r/\Aaudit_log_events_y(\d{4})h([12])\z/
  @lock_key "oli.audit_log_events.partitions"
  @warning_future_intervals 3

  @type report :: %{created: [String.t()], covered_through: Date.t()}

  @doc """
  Returns the partition name for the half-year containing `date`.

      iex> Oli.Auditing.Partitions.name_for(~D[2026-07-01])
      "audit_log_events_y2026h2"
  """
  @spec name_for(Date.t()) :: String.t()
  def name_for(%Date{} = date) do
    %Date{year: year} = start = interval_start(date)
    "#{@table}_y#{year}#{half(start)}"
  end

  @doc """
  Returns the `[from, to)` bounds of the half-year containing `date`.

      iex> Oli.Auditing.Partitions.bounds(~D[2026-06-30])
      {~D[2026-01-01], ~D[2026-07-01]}
  """
  @spec bounds(Date.t()) :: {Date.t(), Date.t()}
  def bounds(%Date{} = date) do
    start = interval_start(date)
    {start, Date.shift(start, month: 6)}
  end

  @doc """
  Creates every missing partition from the current half-year through the one containing
  `date`. Idempotent; concurrent callers do not block each other: the one that does not get
  the advisory lock returns the current coverage without DDL.
  """
  @spec ensure_through(Date.t()) :: {:ok, report()} | {:error, Error.t()}
  def ensure_through(%Date{} = date) do
    Repo.transaction(fn ->
      case Repo.query!("SELECT pg_try_advisory_xact_lock(hashtext($1))", [@lock_key]) do
        %{rows: [[true]]} -> create_missing(date)
        %{rows: [[false]]} -> []
      end
    end)
    |> case do
      {:ok, created} ->
        {:ok, %{created: created, covered_through: covered_through(existing_starts())}}

      {:error, _reason} ->
        {:error, provisioning_error()}
    end
  rescue
    error in [Postgrex.Error, DBConnection.ConnectionError] ->
      Logger.error("Audit partition provisioning failed: #{Exception.message(error)}")
      {:error, provisioning_error()}
  end

  @doc """
  Reports partition coverage: `:error` when the current half-year has no partition,
  `:warning` when fewer than #{@warning_future_intervals} consecutive future half-years exist,
  `:ok` otherwise.
  """
  @spec status() ::
          {:ok | :warning | :error,
           %{
             covered_through: Date.t() | nil,
             current: String.t(),
             future_intervals: non_neg_integer()
           }}
  def status do
    today = Date.utc_today()
    starts = existing_starts()
    current = interval_start(today)

    future =
      current
      |> Date.shift(month: 6)
      |> half_years_from()
      |> Enum.take_while(&MapSet.member?(starts, &1))
      |> length()

    level =
      case {MapSet.member?(starts, current), future} do
        {false, _} -> :error
        {true, future} when future < @warning_future_intervals -> :warning
        {true, _} -> :ok
      end

    {level,
     %{
       covered_through: covered_through(starts),
       current: name_for(today),
       future_intervals: future
     }}
  end

  @doc """
  Detaches a partition from `audit_log_events`, leaving it as a standalone table. For
  rehearsals and operators only; nothing calls it on a schedule.

  A plain `DETACH` needs ACCESS EXCLUSIVE on the parent, so it gives up after a five-second lock
  timeout instead of queueing every read and write behind a long query. Production removal uses
  `DETACH PARTITION ... CONCURRENTLY` (see `docs/runbooks/audit-log/partitioned-storage.md`).

  Returns `{:error, :invalid_name}` for a name that is not a partition name and
  `{:error, :not_found}` when no such partition is attached.
  """
  @spec detach(String.t()) :: :ok | {:error, :invalid_name | :not_found}
  def detach(name) when is_binary(name) do
    with true <- Regex.match?(@name_pattern, name) || {:error, :invalid_name},
         true <- name in attached_partitions() || {:error, :not_found},
         {:ok, :ok} <- Repo.transaction(fn -> detach!(name) end) do
      :ok
    end
  end

  defp detach!(name) do
    Repo.query!("SET LOCAL lock_timeout = '5s'")
    Repo.query!("ALTER TABLE #{@table} DETACH PARTITION #{name}")
    :ok
  end

  defp create_missing(date) do
    starts = existing_starts()
    last = interval_start(date)

    Date.utc_today()
    |> interval_start()
    |> half_years_from()
    |> Enum.take_while(&(Date.compare(&1, last) != :gt))
    |> Enum.reject(&MapSet.member?(starts, &1))
    |> Enum.map(&create_partition/1)
  end

  # Creates the table first and then attaches it. `CREATE TABLE ... PARTITION OF` needs ACCESS
  # EXCLUSIVE on the parent, so behind a long read every insert would queue for up to the lock
  # timeout; `ATTACH PARTITION` needs only SHARE UPDATE EXCLUSIVE, which reads and writes do not
  # conflict with. The new table is empty, so the attach's bounds validation costs nothing.
  defp create_partition(start) do
    name = name_for(start)
    {from, to} = bounds(start)

    Repo.query!("SET LOCAL lock_timeout = '5s'")

    Repo.query!("""
    CREATE TABLE #{name}
      (LIKE #{@table} INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING GENERATED)
    """)

    Repo.query!("""
    ALTER TABLE #{@table} ATTACH PARTITION #{name}
      FOR VALUES FROM ('#{Date.to_iso8601(from)} 00:00:00+00') TO ('#{Date.to_iso8601(to)} 00:00:00+00')
    """)

    # Statement triggers are not inherited from the parent, so each partition blocks TRUNCATE.
    Repo.query!("""
    CREATE TRIGGER audit_log_events_no_truncate
      BEFORE TRUNCATE ON #{name}
      FOR EACH STATEMENT EXECUTE FUNCTION audit_log_events_append_only()
    """)

    name
  end

  defp attached_partitions do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT child.relname
        FROM pg_inherits
        JOIN pg_class parent ON parent.oid = pg_inherits.inhparent
        JOIN pg_class child ON child.oid = pg_inherits.inhrelid
        WHERE parent.relname = $1
        """,
        [@table]
      )

    Enum.map(rows, fn [name] -> name end)
  end

  defp existing_starts do
    attached_partitions()
    |> Enum.flat_map(fn name ->
      case Regex.run(@name_pattern, name) do
        [_, year, "1"] -> [Date.new!(String.to_integer(year), 1, 1)]
        [_, year, "2"] -> [Date.new!(String.to_integer(year), 7, 1)]
        nil -> []
      end
    end)
    |> MapSet.new()
  end

  # The last day of the furthest consecutive partition, starting from the current half-year.
  defp covered_through(starts) do
    Date.utc_today()
    |> interval_start()
    |> half_years_from()
    |> Enum.take_while(&MapSet.member?(starts, &1))
    |> List.last()
    |> case do
      nil -> nil
      start -> start |> Date.shift(month: 6) |> Date.add(-1)
    end
  end

  # Consecutive half-year starts beginning at `start`.
  defp half_years_from(start), do: Stream.iterate(start, &Date.shift(&1, month: 6))

  defp interval_start(%Date{year: year, month: month}) when month < 7, do: Date.new!(year, 1, 1)
  defp interval_start(%Date{year: year}), do: Date.new!(year, 7, 1)

  defp half(%Date{month: 1}), do: "h1"
  defp half(%Date{month: 7}), do: "h2"

  defp provisioning_error, do: Error.new(:partition_missing)
end
