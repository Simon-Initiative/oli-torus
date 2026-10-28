defmodule Oli.GenAI.PoolManager do
  @moduledoc "Reconciles per-node logical transport pools; physical capacity remains owned by Hackney."
  use GenServer
  alias Oli.GenAI.{Provider, TransportPool}

  @doc "Starts the node's pool reconciler."
  def start_link(opts \\ []) do
    case Keyword.get(opts, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, opts)
      name -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @doc "Applies the complete committed set of logical pool specifications."
  def reconcile(manager \\ __MODULE__, specs),
    do: GenServer.call(manager, {:reconcile, specs}, 30_000)

  @doc "Returns a logical coordinator, not a stale physical generation handle."
  def lookup(manager \\ __MODULE__, key), do: GenServer.call(manager, {:lookup, key})

  @doc "Returns the explicit administrative pool key for a Provider and realized model origin."
  def administrative_key(provider, model) do
    with {:ok, origin} <- Provider.origin(Provider.endpoint(provider, model)) do
      digest = :crypto.hash(:sha256, :erlang.term_to_binary(origin))
      {:ok, {:administrative, provider.id, digest}}
    end
  end

  @doc "Checks out a connection through its logical pool's initiation fence."
  def connect(manager \\ __MODULE__, key, url, opts \\ []) do
    with {:ok, pool} <- lookup(manager, key), do: TransportPool.connect(pool, url, opts)
  end

  @doc "Returns current and retiring generation observations for diagnostics."
  def snapshot(manager \\ __MODULE__), do: GenServer.call(manager, :snapshot, 30_000)

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    namespace = Keyword.get(opts, :namespace, :production)
    poll_ms = Keyword.get(opts, :poll_ms, 1_000)
    # Recover even generations whose logical configuration was deleted before a
    # manager restart; otherwise no future desired key would adopt them.
    orphan_keys =
      for {{:genai_transport, {^namespace, key}, _}, _} <- :ets.tab2list(:hackney_pool), do: key

    retired =
      orphan_keys
      |> Enum.uniq()
      |> Map.new(fn key ->
        {:ok, pid} = TransportPool.start_link(key: {namespace, key}, poll_ms: poll_ms)
        {key, pid}
      end)

    state = %{pools: %{}, retired: retired, poll_ms: poll_ms, namespace: namespace}

    Process.send_after(self(), :collect, state.poll_ms)
    {:ok, state}
  end

  @impl true
  def handle_call({:lookup, key}, _from, state) do
    case Map.fetch(state.pools, key) do
      {:ok, pid} -> {:reply, {:ok, pid}, state}
      :error -> {:reply, {:error, :pool_unavailable}, state}
    end
  end

  def handle_call({:reconcile, specs}, _from, state) do
    removed = Map.keys(state.pools) -- Map.keys(specs)

    retired =
      Enum.reduce(removed, state.retired, fn key, retired ->
        pid = state.pools[key]
        :ok = TransportPool.retire(pid)
        Map.put(retired, key, pid)
      end)

    {pools, retired} =
      Enum.reduce(specs, {Map.drop(state.pools, removed), retired}, fn {key, spec},
                                                                       {pools, retired} ->
        pid =
          case pools[key] || retired[key] do
            nil ->
              {:ok, pid} =
                TransportPool.start_link(key: {state.namespace, key}, poll_ms: state.poll_ms)

              pid

            pid ->
              pid
          end

        :ok = TransportPool.configure(pid, spec)
        {Map.put(pools, key, pid), Map.delete(retired, key)}
      end)

    {:reply, :ok, %{state | pools: pools, retired: retired}}
  end

  def handle_call(:snapshot, _from, state) do
    snapshots = Map.new(state.pools, fn {key, pid} -> {key, TransportPool.snapshot(pid)} end)
    retired = Map.new(state.retired, fn {key, pid} -> {key, TransportPool.snapshot(pid)} end)
    {:reply, %{pools: snapshots, retiring: retired}, state}
  end

  @impl true
  def handle_info(:collect, state) do
    retired =
      Map.reject(state.retired, fn {_, pid} ->
        case TransportPool.snapshot(pid) do
          %{current: nil, retired: []} ->
            GenServer.stop(pid)
            true

          _ ->
            false
        end
      end)

    Process.send_after(self(), :collect, state.poll_ms)
    {:noreply, %{state | retired: retired}}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    case reason do
      :normal ->
        :ok

      _ ->
        :telemetry.execute([:oli, :genai, :pool, :lifecycle], %{count: 1}, %{
          event: :coordinator_exit
        })
    end

    pools = Map.reject(state.pools, fn {_, existing} -> existing == pid end)
    retired = Map.reject(state.retired, fn {_, existing} -> existing == pid end)
    {:noreply, %{state | pools: pools, retired: retired}}
  end

  @impl true
  def terminate(_reason, state) do
    Enum.each(Map.values(state.pools) ++ Map.values(state.retired), fn pid ->
      case Process.alive?(pid) do
        true ->
          TransportPool.retire(pid)
          send(pid, :collect)
          GenServer.stop(pid)

        false ->
          :ok
      end
    end)
  end
end
