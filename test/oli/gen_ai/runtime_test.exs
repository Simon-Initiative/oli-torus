# Acceptance coverage: AC-008, AC-013.
defmodule Oli.GenAI.RuntimeTest do
  use Oli.DataCase, async: false
  alias Oli.GenAI
  alias Oli.GenAI.{Configuration, PoolManager, Runtime}

  test "independent node-local reconcilers apply committed settings and immediate pool replacement" do
    {provider, model, config} = configuration()
    tasks = start_supervised!({Task.Supervisor, max_children: 2})

    managers =
      for _ <- 1..2 do
        start_supervised!(
          Supervisor.child_spec({PoolManager, name: nil, namespace: make_ref(), poll_ms: 10},
            id: make_ref()
          )
        )
      end

    runtimes = Enum.map(managers, fn manager -> start_runtime(manager, tasks) end)

    try do
      for {runtime, _} <- runtimes do
        assert :ok = Runtime.reconcile(runtime)
        refute Runtime.snapshot(runtime).observe_only
        refute Runtime.snapshot(runtime).providers[provider.id].monitoring_enabled
      end

      key = {config.id, :primary}
      names = Enum.map(managers, &PoolManager.snapshot(&1).pools[key].current.name)
      refute Enum.at(names, 0) == Enum.at(names, 1)
      assert {:ok, _} = GenAI.update_service_config(config, %{primary_pool_capacity: 7})

      for manager <- managers do
        eventually(fn -> PoolManager.snapshot(manager).pools[key].current.capacity == 7 end)
      end

      assert {:ok, updated} = GenAI.update_provider(provider, %{api_key: "new-credential"})

      for {runtime, _} <- runtimes do
        assert :ok = Runtime.reconcile(runtime)
        snapshot = Runtime.snapshot(runtime)
        assert snapshot.providers[provider.id].health_check_model_id == model.id
        refute inspect(snapshot) =~ updated.api_key
      end
    after
      Enum.each(runtimes, fn {_, id} -> stop_supervised(id) end)
    end
  end

  test "periodic reload repairs missed invalidation and keeps the last good config on load failure" do
    {_provider, _model, config} = configuration()
    tasks = start_supervised!({Task.Supervisor, max_children: 1})
    manager = start_supervised!({PoolManager, name: nil, namespace: make_ref(), poll_ms: 10})
    source = start_supervised!({Agent, fn -> Configuration.runtime_configuration() end})

    source_fun = fn ->
      case Agent.get(source, & &1) do
        :failed -> raise "simulated configuration load failure"
        config -> config
      end
    end

    {runtime, id} = start_runtime(manager, tasks, source: source_fun, interval_ms: 20)

    try do
      assert :ok = Runtime.reconcile(runtime)
      key = {config.id, :primary}
      name = PoolManager.snapshot(manager).pools[key].current.name

      Agent.update(source, fn current ->
        configs =
          Enum.map(current.service_configs, fn entry ->
            case entry.id == config.id do
              true -> %{entry | primary_pool_capacity: 11}
              false -> entry
            end
          end)

        %{current | service_configs: configs}
      end)

      eventually(fn -> PoolManager.snapshot(manager).pools[key].current.capacity == 11 end)
      refute PoolManager.snapshot(manager).pools[key].current.name == name
      Agent.update(source, fn _ -> :failed end)
      assert {:error, :configuration_load_failed} = Runtime.reconcile(runtime)
      assert PoolManager.snapshot(manager).pools[key].current.capacity == 11
    after
      stop_supervised(id)
    end
  end

  test "the production runtime supervisor starts reconciled infrastructure with checks disabled" do
    settings = Application.get_env(:oli, :genai_health, [])
    Application.put_env(:oli, :genai_health, Keyword.put(settings, :enabled, false))

    try do
      start_supervised!(Oli.GenAI.RuntimeSupervisor)
      assert :ok = Runtime.reconcile()
      refute Runtime.snapshot().observe_only
      assert Process.whereis(Oli.GenAI.HealthTasks)
      assert Process.whereis(PoolManager)
    after
      stop_supervised(Oli.GenAI.RuntimeSupervisor)
      Application.put_env(:oli, :genai_health, settings)
    end
  end

  defp configuration do
    {:ok, provider} =
      GenAI.create_provider(%{
        name: "Runtime provider",
        adapter: :open_ai,
        base_url: "http://127.0.0.1:9999",
        api_key: "runtime-key"
      })

    {:ok, model} =
      GenAI.create_registered_model(%{
        name: "Runtime model",
        provider: :open_ai,
        provider_id: provider.id,
        model: "test-model",
        url_template: provider.base_url,
        api_key: "legacy-key"
      })

    {:ok, config} =
      GenAI.create_service_config(%{name: "Runtime configuration", primary_model_id: model.id})

    {provider, model, config}
  end

  defp start_runtime(manager, tasks, opts \\ []) do
    id = make_ref()

    runtime =
      start_supervised!(
        Supervisor.child_spec(
          {Runtime,
           [
             name: nil,
             pool_manager: manager,
             task_supervisor: tasks,
             enabled: false,
             jitter_ms: 0
           ] ++ opts},
          id: id
        )
      )

    {runtime, id}
  end

  defp eventually(fun, attempts \\ 100)
  defp eventually(fun, 0), do: assert(fun.())

  defp eventually(fun, attempts) do
    case fun.() do
      true ->
        :ok

      false ->
        Process.sleep(10)
        eventually(fun, attempts - 1)
    end
  end
end
