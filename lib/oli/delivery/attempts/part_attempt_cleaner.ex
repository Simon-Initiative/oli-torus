defmodule Oli.Delivery.Attempts.PartAttemptCleaner do
  @moduledoc """
    Long running process that deletes the unneeded part attempts
    which had been created due to the part attempt bloat bug.
  """

  use GenServer

  alias Phoenix.PubSub
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, PartAttempt}

  import Ecto.Query, warn: false
  alias Oli.Repo

  require Logger

  @default_wait_time_in_ms 1000


  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

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

    Logger.info("PartAttemptCleaner status: #{inspect(state)}")

    {:reply, state, state}
  end

  def handle_cast({:stop}, state) do

    Logger.info("PartAttemptCleaner stopping")

    state = Map.put(state, :running, false)
    {:noreply, state}
  end

  def handle_cast({:start}, state) do
    state = Map.put(state, :running, true)

    Logger.info("PartAttemptCleaner starting")

    next(self())

    {:noreply, state}
  end

  def handle_cast({:seed, project_ids}, state) do

    Logger.info("PartAttemptCleaner seeding")

    do_seed(project_ids)
    PubSub.broadcast(OliWeb.PubSub, "part_attempt_cleaner", {:seed_complete})

    {:noreply, state}
  end

  def handle_info({:batch_finished, details}, state) do

    Logger.info("PartAttemptCleaner batch finished")

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

    PubSub.broadcast(OliWeb.PubSub, "part_attempt_cleaner", {:batch_finished, state})

    {:noreply, state}
  end

  def handle_info({:no_more_attempts}, state) do

    Logger.info("PartAttemptCleaner no more attempts")

    PubSub.broadcast(OliWeb.PubSub, "part_attempt_cleaner", {:no_more_attempts})

    state = Map.put(state, :running, false)
    {:noreply, state}
  end

  def handle_info({:quiet_period_elapsed}, state) do

    Logger.info("PartAttemptCleaner quiet period elapsed")

    if state.running do
      next(self())
    end

    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def next(pid) do
    Task.async(fn ->
      case do_next() do
        {:ok, {count, visited}} ->
          Logger.info("PartAttemptCleaner deleted #{count} part attempts")
          Process.send(pid, {:batch_finished, %{records_deleted: count, records_visited: visited}}, [])

        {:error, :no_more_attempts} ->
          Logger.warning("PartAttemptCleaner cannot find attempts to process")
          Process.send(pid, {:no_more_attempts}, [])


        {:error, e} ->
          Logger.error("PartAttemptCleaner encountered error [#{e}]")

      end
    end)
  end

  def do_next() do
    Repo.transaction(fn ->
      with {:ok, id} <- get_next_attempt_id(),
        {:ok, part_attempts} <- read_part_attempts(id),
        {:ok, to_delete} <- determine_which_to_delete(part_attempts) do

        total = length(part_attempts)
        count = issue_delete(to_delete)

        {count, total}
      else
        {:error, :no_more_attempts} ->
          Repo.rollback(:no_more_attempts)

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

  def determine_which_to_delete(part_attempts) do

    # separate into groups by part_id
    to_delete = Enum.group_by(part_attempts, &(&1.part_id))
    |> Enum.map(fn {_part_id, attempts} ->

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

  # Sorts a group of part records by lifecycle state and updated_at and then id.
  # The sort order is a key aspect of the algorithm to determine which
  # record to keep (and thus which to delete). This sort places the
  # record to keep as the last item, so that we can Enum.take all but the last.
  def sort(part_attempts) do
    Enum.sort(part_attempts, fn a, b ->
      if a.lifecycle_state == b.lifecycle_state do
        case DateTime.compare(a.updated_at, b.updated_at) do
          :lt -> true
          :gt -> false
          :eq -> a.id > b.id
        end
      else
        a.lifecycle_state < b.lifecycle_state
      end
    end)
  end

  defp read_part_attempts(id) do
    results = Repo.all(
      from(p in PartAttempt,
      where: p.activity_attempt_id == ^id and p.attempt_number == 1,
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


end
