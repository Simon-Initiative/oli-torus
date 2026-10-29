defmodule Oli.GenAI.Runtime do
  @moduledoc "Node-local reconciliation of durable Provider configuration and transport pools."
  use GenServer
  alias Oli.GenAI.{Configuration, HealthMonitor, HealthProbe, PoolManager, Provider}

  @doc "Starts node-local reconciliation; tests can supply a deterministic configuration source."
  def start_link(opts \\ []) do
    case Keyword.get(opts, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, opts)
      name -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @doc "Reloads committed configuration, also used to recover from missed PubSub invalidations."
  def reconcile(runtime \\ __MODULE__), do: GenServer.call(runtime, :reconcile, 60_000)

  @doc "Returns health snapshots and safe reconciliation status without credentials."
  def snapshot(runtime \\ __MODULE__), do: GenServer.call(runtime, :snapshot, 15_000)

  @doc "Returns private execution inputs from the last reconciled configuration (includes credentials)."
  def routing_configuration(id, runtime \\ __MODULE__) do
    with pid when is_pid(pid) <- GenServer.whereis(runtime),
         table when not is_nil(table) <- :persistent_term.get({__MODULE__, pid}, nil),
         [{_, inputs}] <- :ets.lookup(table, {:config, id}) do
      health =
        Map.new(inputs.monitors, fn {id, monitor} -> {id, monitor_snapshot(id, monitor)} end)

      {:ok, inputs |> Map.delete(:monitors) |> Map.put(:health, health)}
    else
      _ -> {:error, :configuration_unavailable}
    end
  rescue
    ArgumentError -> {:error, :configuration_unavailable}
  end

  @doc "Returns current private model/Provider inputs for explicit administrative transport."
  def administrative_configuration(id, runtime \\ __MODULE__) do
    with pid when is_pid(pid) <- GenServer.whereis(runtime),
         table when not is_nil(table) <- :persistent_term.get({__MODULE__, pid}, nil),
         [{_, inputs}] <- :ets.lookup(table, {:model, id}) do
      {:ok, inputs}
    else
      _ -> {:error, :configuration_unavailable}
    end
  rescue
    ArgumentError -> {:error, :configuration_unavailable}
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    :ok = Phoenix.PubSub.subscribe(Oli.PubSub, Configuration.topic())
    manager = Keyword.get(opts, :pool_manager, PoolManager)

    probe =
      Keyword.get(opts, :probe, fn provider, model ->
        HealthProbe.run(provider, model, manager)
      end)

    settings = Application.get_env(:oli, :genai_health, [])

    enabled = Keyword.get(opts, :enabled, Keyword.get(settings, :enabled, true))

    table = :ets.new(__MODULE__, [:protected, :set, read_concurrency: true])
    owner = self()
    cache_key = {__MODULE__, owner}
    :persistent_term.put(cache_key, table)
    # The table disappears with its owner; also reclaim its discovery handle on :kill.
    spawn(fn ->
      ref = Process.monitor(owner)

      receive do
        {:DOWN, ^ref, :process, ^owner, _} -> :persistent_term.erase(cache_key)
      end
    end)

    state = %{
      cache: table,
      source:
        Keyword.get(opts, :source, fn ->
          Configuration.runtime_configuration(reconcile_probes: enabled)
        end),
      pool_manager: manager,
      task_supervisor: Keyword.fetch!(opts, :task_supervisor),
      probe: probe,
      enabled: enabled,
      jitter_ms: Keyword.get(opts, :jitter_ms, 5_000),
      interval_ms: Keyword.get(opts, :interval_ms, 30_000),
      monitors: %{},
      providers: %{},
      configs: %{},
      timer: nil,
      last_reconciled_at: nil,
      error: nil,
      service_config_issues: %{}
    }

    send(self(), :reconcile)
    {:ok, state}
  end

  @impl true
  def handle_call(:reconcile, _from, state) do
    state = load(state)

    {:reply,
     case state.error do
       nil -> :ok
       error -> {:error, error}
     end, state}
  end

  def handle_call(:snapshot, _from, state) do
    providers = Map.new(state.monitors, fn {id, pid} -> {id, monitor_snapshot(id, pid)} end)

    {:reply,
     %{
       providers: providers,
       last_reconciled_at: state.last_reconciled_at,
       error: state.error,
       observe_only: false,
       service_config_issues: state.service_config_issues
     }, state}
  end

  @impl true
  def handle_info(:reconcile, state), do: {:noreply, load(state)}
  def handle_info(:genai_configuration_changed, state), do: {:noreply, load(state)}

  def handle_info({:EXIT, pid, _reason}, state) do
    monitors = Map.reject(state.monitors, fn {_, existing} -> existing == pid end)
    {:noreply, %{state | monitors: monitors}}
  end

  @impl true
  def terminate(_reason, state) do
    Enum.each(state.monitors, fn {_, pid} ->
      case Process.alive?(pid) do
        true -> GenServer.stop(pid)
        false -> :ok
      end
    end)
  end

  defp load(state) do
    case state.timer do
      nil -> :ok
      timer -> Process.cancel_timer(timer)
    end

    started = System.monotonic_time(:millisecond)

    state =
      try do
        %{providers: providers, service_configs: configs} = loaded = state.source.()
        provider_map = Map.new(providers, &{&1.provider.id, &1.provider})
        specs = pool_specs(providers, configs, provider_map)
        :ok = PoolManager.reconcile(state.pool_manager, specs)
        ids = Enum.map(providers, & &1.provider.id)

        Enum.each(state.monitors, fn {id, pid} ->
          case id in ids do
            true -> :ok
            false -> GenServer.stop(pid)
          end
        end)

        monitors = Map.take(state.monitors, ids)

        monitors =
          Enum.reduce(providers, monitors, fn entry, monitors ->
            config = entry |> Map.take([:provider, :model]) |> Map.put(:enabled, state.enabled)

            pid =
              case Map.get(monitors, entry.provider.id) do
                nil ->
                  {:ok, pid} =
                    HealthMonitor.start_link(
                      config: config,
                      task_supervisor: state.task_supervisor,
                      probe: state.probe,
                      jitter_ms: state.jitter_ms
                    )

                  pid

                pid ->
                  :ok = HealthMonitor.configure(pid, config)
                  pid
              end

            Map.put(monitors, entry.provider.id, pid)
          end)

        entries =
          Enum.map(configs, fn config ->
            ids = provider_ids(config)

            {{:config, config.id},
             %{
               config: config,
               providers: Map.take(provider_map, ids),
               monitors: Map.take(monitors, ids),
               pool_manager: state.pool_manager
             }}
          end)

        model_entries =
          for entry <- providers,
              model <- Map.get(entry, :models, List.wrap(entry.model)) do
            {{:model, model.id},
             %{model: model, provider: entry.provider, pool_manager: state.pool_manager}}
          end

        # Replace model entries as one atomic publication so deleted models cannot
        # retain an administrative transport lookup after reconciliation.
        current_model_ids = MapSet.new(model_entries, fn {{:model, id}, _} -> id end)

        for {{:model, id}, _} <- :ets.tab2list(state.cache),
            not MapSet.member?(current_model_ids, id),
            do: :ets.delete(state.cache, {:model, id})

        true = :ets.insert(state.cache, entries ++ model_entries)

        Enum.each(Map.keys(state.configs) -- Enum.map(configs, & &1.id), fn id ->
          :ets.delete(state.cache, {:config, id})
        end)

        :telemetry.execute(
          [:oli, :genai, :configuration, :reconciled],
          %{
            duration_ms: System.monotonic_time(:millisecond) - started,
            providers: length(providers),
            service_configs: length(configs)
          },
          %{outcome: :ok}
        )

        %{
          state
          | monitors: monitors,
            providers: provider_map,
            configs: Map.new(configs, &{&1.id, &1}),
            last_reconciled_at: DateTime.utc_now(),
            error: nil,
            service_config_issues: Map.get(loaded, :service_config_issues, %{})
        }
      rescue
        _ ->
          :telemetry.execute([:oli, :genai, :health, :monitor_error], %{count: 1}, %{
            category: :configuration_load_failed
          })

          %{state | error: :configuration_load_failed}
      catch
        :exit, _ -> %{state | error: :configuration_load_failed}
      end

    %{state | timer: Process.send_after(self(), :reconcile, state.interval_ms)}
  end

  defp provider_ids(config) do
    [config.primary_model, config.backup_model]
    |> Enum.flat_map(fn
      %{provider_id: id} when not is_nil(id) -> [id]
      _ -> []
    end)
  end

  defp monitor_snapshot(id, pid) do
    HealthMonitor.snapshot(pid)
  catch
    :exit, _ ->
      %{
        provider_id: id,
        observed: :unknown,
        eligible: false,
        failure_category: :monitor_unavailable
      }
  end

  defp pool_specs(providers, configs, provider_map) do
    base =
      Enum.reduce(providers, %{}, fn %{provider: provider, model: model} = entry, specs ->
        case {provider.adapter, Provider.origin(Provider.endpoint(provider, model))} do
          {:open_ai, {:ok, origin}} ->
            signature = {provider.config_version, model && model.id}

            specs =
              Map.put(specs, {:probe, provider.id}, %{
                origin: origin,
                capacity: 1,
                signature: signature
              })

            Enum.reduce(Map.get(entry, :models, List.wrap(model)), specs, fn candidate, specs ->
              with {:ok, admin_origin} <- Provider.origin(Provider.endpoint(provider, candidate)),
                   {:ok, key} <- PoolManager.administrative_key(provider, candidate) do
                Map.put(specs, key, %{
                  origin: admin_origin,
                  capacity: 4,
                  signature: provider.config_version
                })
              else
                _ -> specs
              end
            end)

          _ ->
            specs
        end
      end)

    Enum.reduce(configs, base, fn config, specs ->
      Enum.reduce([:primary, :secondary, :backup], specs, fn tier, specs ->
        model = Map.get(config, model_field(tier))
        provider = model && provider_map[model.provider_id]

        case {model, provider} do
          {%Oli.GenAI.Completions.RegisteredModel{}, %Provider{adapter: :open_ai} = provider} ->
            case Provider.origin(Provider.endpoint(provider, model)) do
              {:ok, origin} ->
                Map.put(specs, {config.id, tier}, %{
                  origin: origin,
                  capacity: Map.fetch!(config, capacity_field(tier)),
                  signature: Oli.GenAI.Provider.transport_signature(provider, model)
                })

              _ ->
                specs
            end

          _ ->
            specs
        end
      end)
    end)
  end

  defp model_field(:primary), do: :primary_model
  defp model_field(:secondary), do: :secondary_model
  defp model_field(:backup), do: :backup_model
  defp capacity_field(:primary), do: :primary_pool_capacity
  defp capacity_field(:secondary), do: :secondary_pool_capacity
  defp capacity_field(:backup), do: :backup_pool_capacity
end
