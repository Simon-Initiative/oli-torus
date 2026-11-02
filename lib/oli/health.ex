defmodule Oli.Health do
  @moduledoc """
  Node-local startup, liveness and readiness state.

  Startup completion and draining are independent atomic flags: completion can
  never clear a concurrent drain request. Only a new application start resets
  them. Reads do not depend on a health process or any external service.
  """

  @state_key {__MODULE__, :lifecycle}
  @database_budget_ms 1_000
  @required_services [Oli.Repo, Oli.PubSub, Oli.Vault]

  @doc "Resets lifecycle state before application children start."
  @spec starting() :: :ok
  def starting do
    :persistent_term.put(@state_key, :atomics.new(2, signed: false))
  end

  @doc "Marks mandatory startup complete without clearing a requested drain."
  @spec started() :: :ok
  def started do
    case :persistent_term.get(@state_key, nil) do
      nil -> :ok
      flags -> :atomics.put(flags, 1, 1)
    end
  end

  @doc "Idempotently stops readiness on this node without stopping HTTP or liveness."
  @spec drain() :: :ok
  def drain do
    case :persistent_term.get(@state_key, nil) do
      nil -> :ok
      flags -> :atomics.put(flags, 2, 1)
    end
  end

  @doc "Returns the local lifecycle state; uninitialized nodes are starting."
  @spec state() :: :starting | :running | :draining
  def state do
    case :persistent_term.get(@state_key, nil) do
      nil ->
        :starting

      flags ->
        case {:atomics.get(flags, 1), :atomics.get(flags, 2)} do
          {_, 1} -> :draining
          {1, 0} -> :running
          {0, 0} -> :starting
        end
    end
  end

  @doc "Reports only startup completion, including while draining or dependencies fail."
  @spec live?() :: boolean()
  def live? do
    case :persistent_term.get(@state_key, nil) do
      nil -> false
      flags -> :atomics.get(flags, 1) == 1
    end
  end

  @doc """
  Checks startup, drain, required local services and the normal repository pool.

  Checkout and `SELECT 1` share a one-second deadline. The caller also enforces
  that budget and kills and joins expired work, including a queued checkout.
  Database failures are private and never change liveness. Lifecycle and local
  availability are rechecked after the query to catch a concurrent drain.
  """
  @spec ready?() :: boolean()
  def ready? do
    state() == :running and services_available?() and database_ready?() and
      state() == :running and services_available?()
  end

  defp services_available? do
    Enum.all?(@required_services, fn name ->
      case Process.whereis(name) do
        nil -> false
        pid -> Process.alive?(pid)
      end
    end)
  end

  defp database_ready? do
    deadline = System.monotonic_time(:millisecond) + @database_budget_ms
    repo = Oli.Repo.get_dynamic_repo()
    task = Task.async(fn -> query_database(repo, deadline) end)
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    case Task.yield(task, remaining) || Task.shutdown(task, :brutal_kill) do
      {:ok, true} -> System.monotonic_time(:millisecond) < deadline
      _ -> false
    end
  end

  defp query_database(repo, deadline) do
    case Ecto.Adapters.SQL.query(repo, "SELECT 1", [],
           timeout: @database_budget_ms,
           deadline: deadline,
           log: false
         ) do
      {:ok, %{rows: [[1]]}} -> true
      _ -> false
    end
  rescue
    _ -> false
  catch
    :exit, _ -> false
  end
end
