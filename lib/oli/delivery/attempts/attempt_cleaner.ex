defmodule Oli.Delivery.Attempts.PartAttemptRemediator do
  @moduledoc """
    Long running process that deletes the unneeded part attempts for a given activity attempt,
    which had been created due to the part attempt bloat bug.
  """

  use GenServer
  alias Oli.Delivery.Attempts.PartAttemptRemediator
  alias Phoenix.PubSub
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, PartAttempt, ResourceAttempt, ResourceAccess}
  alias Oli.Delivery.Sections.Section

  import Ecto.Query, warn: false
  alias Oli.Repo

  require Logger

  @default_wait_time_in_ms 1000

  # ----------------
  # Client

  def start_link(init_args),
    do: GenServer.start_link(__MODULE__, init_args, name: __MODULE__)

  def stop(),
    do: GenServer.cast(__MODULE__, {:stop})

  def start(),
    do: GenServer.cast(__MODULE__, {:start})

  def status(),
    do: GenServer.call(__MODULE__, {:status})

  def seed(project_ids),
    do: GenServer.cast(__MODULE__, {:seed, project_ids})


  # ----------------
  # Server callbacks

  def init(_) do

    initial_state = %{
      running: false,
      batches_complete: 0,
      records_visited: 0,
      records_deleted: 0,
      wait_time: @default_wait_time_in_ms
    }

    {:ok, initial_state}
  end

  def handle_call({:status}, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:stop}, state) do
    state = Map.put(state, :running, false)
    {:reply, :ok, state}
  end

  def handle_cast({:start}, state) do
    state = Map.put(state, :running, true)

    next(self())

    {:reply, :ok, state}
  end

  def handle_cast({:seed, project_ids}, state) do
    do_seed(project_ids)
    {:noreply, new_state}
  end

  def handle_info({:batch_finished, details}, state) do

    if state.running do
      if state.wait_time > 0 do
        Process.send_after(self(), :quiet_period_elapsed, state.wait_time)
      else
        next(self())
      end
    end

    state = Map.put(state, :batches_complete, state.batches_complete + 1)
    |> Map.put(:records_visited, state.records_visited + details.records_visited)
    |> Map.put(:records_deleted, state.records_deleted + details.records_deleted)

    {:noreply, state}
  end

  def handle_info({:quiet_period_elapsed}, state) do

    if state.running do
      next(self())
    end

    {:noreply, state}
  end


  def next(pid) do
    Task.async(fn ->
      case do_next() do
        {:ok, {count, visited}} ->
          Logger.info("PartAttemptRemediator deleted #{count} part attempts")
          Process.send(pid, {:batch_finished, %{records_deleted: count, records_visited: visited}}

        {:error, :no_more_attempts} ->
          Logger.warning("PartAttemptRemediator cannot find attempts to process")

        {:error, e} ->
          Logger.error("PartAttemptRemediator encountered error [#{e}]")

      end
    end)
  end

  def do_next() do
    Repo.transaction(fn ->
      with {:ok, id} <- get_next_attempt_id(),
        {:ok, part_attempts} <- read_part_attempts(id),
        {:ok, to_delete} <- determine_which_to_delete(part_attempts) do

        total = length(part_attempts)
        count = issue_delete(to_delete, total)

        {count, total}
      else
        e ->
          Repo.rollback(e)
      end
    end)
  end

  defp issue_delete([]), do: 0
  defp issue_delete(part_attempt_ids) do
    {count, _} = Repo.delete_all(
      from(p in PartAttempt,
      where: p.id in ^part_attempt_ids
    ))
    count
  end

  defp determine_which_to_delete(part_attempts) do

    # separate into groups by part_id
    to_delete = Enum.group_by(part_attempts, &(&1.part_id))
    |> Enum.map(fn {part_id, attempts} ->

      len = length(attempts)

      if len == 1 do
        []
      else
        # sort by lifecycle state and then updated_at, then
        # take all but the last one
        sort(attempts)
        |> Enum.take(len - 1)
      end
    end)
    |> List.flatten()
    |> Enum.map(&(&1.id))

    {:ok, to_delete}
  end

  def sort(part_attempts) do
    Enum.sort(part_attempts, fn a, b ->
      if a.lifecycle_state == b.lifecycle_state do
        a.updated_at < b.updated_at
      else
        a.lifecycle_state < b.lifecycle_state
      end
    end)
  end

  defp read_part_attempts(id) do
    results = Repo.all(
      from(p in PartAttempt,
      where: p.activity_attempt_id = ^id and p.attempt_number == 1,
      select: %{
        id: p.id,
        part_id: p.part_id,
        lifecycle_state: p.lifecycle_state,
        updated_at: p.updated_at
      }
    ))

    {:ok, results}
  end

  defp get_next_attempt_id() do
    case Repo.all(
      from(a in ActivityAttempt,
      where: a.cleanup == 1,
      order_by: [asc: a.inserted_at],
      select: a.id,
      limit: 1
    )) do

      [id] -> {:ok, id}

      [] -> {:error, :no_more_attempts}

    end
  end

  def do_seed(project_ids) do
    query = """
    UPDATE activity_attempts
    SET cleanup = 1
    WHERE id IN (
        SELECT a.id
        FROM sections s
        JOIN resource_accesses ra ON ra.section_id = s.id
        JOIN resource_attempts r ON r.resource_access_id = ra.id
        JOIN activity_attempts a ON a.resource_attempt_id = r.id
        WHERE s.base_project_id IN $1 AND a.cleanup = 0
    );
    """

    Repo.query!(query, [project_ids])
  end

  # ----------------
  # PubSub/Messages callbacks

  def handle_info({:put, key, value, ttl}, state) do
    Cachex.put(@cache_name, key, value, ttl: ttl)

    {:noreply, state}
  end

end
