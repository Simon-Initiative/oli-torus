defmodule Oli.RuntimeLogOverridesTest do
  use ExUnit.Case, async: false

  alias Oli.RuntimeLogOverrides
  alias Oli.RuntimeLogOverrides.Registry

  defmodule FakeRPC do
    defmodule Store do
      @moduledoc false
    end

    def call(node, _module, function, args, _timeout) do
      case Agent.get(Store, &Map.get(&1, {node, function, args})) do
        nil ->
          raise "Missing fake RPC response for #{inspect({node, function, args})}"

        {:raise, exception} ->
          raise exception

        {:exit, reason} ->
          exit(reason)

        response ->
          response
      end
    end
  end

  setup do
    ensure_registry_started()
    ensure_fake_rpc_store_started()

    original_level = Logger.level()
    Logger.delete_all_module_levels()
    Registry.reset()
    Agent.update(FakeRPC.Store, fn _ -> %{} end)

    on_exit(fn ->
      Logger.delete_all_module_levels()
      Registry.reset()
      Logger.configure(level: original_level)
    end)

    :ok
  end

  describe "local system-level operations" do
    test "sets the global logger level through the service boundary" do
      assert {:ok, :error} = RuntimeLogOverrides.set_system_level(:error)
      assert Logger.level() == :error
    end

    test "clears the global logger level back to the configured default" do
      Logger.configure(level: :error)

      assert {:ok, configured_level} = RuntimeLogOverrides.clear_system_level()

      assert configured_level == Application.get_env(:logger, :level)
      assert Logger.level() == Application.get_env(:logger, :level)
    end

    test "rejects invalid global logger levels" do
      assert {:error, :invalid_level} = RuntimeLogOverrides.set_system_level("verbose")
    end
  end

  describe "set_module_level/2" do
    test "applies a module-level override and lists it" do
      assert {:ok, overrides} = RuntimeLogOverrides.set_module_level("Enum", :debug)

      assert [%{target: Enum, target_label: "Elixir.Enum", level: :debug}] = overrides.modules
      assert [] = overrides.processes
      assert [{Enum, :debug}] = Logger.get_module_level(Enum)
    end

    test "does not change the global logger level" do
      Logger.configure(level: :error)

      assert {:ok, _overrides} = RuntimeLogOverrides.set_module_level("Enum", :debug)

      assert Logger.level() == :error
      assert [{Enum, :debug}] = Logger.get_module_level(Enum)
    end

    test "rejects invalid module names" do
      assert {:error, :invalid_module} =
               RuntimeLogOverrides.set_module_level("Not.A.Real.Module", :debug)

      assert [] = RuntimeLogOverrides.list_overrides().modules
    end

    test "rejects invalid levels" do
      assert {:error, :invalid_level} = RuntimeLogOverrides.set_module_level("Enum", "verbose")

      assert [] = RuntimeLogOverrides.list_overrides().modules
      assert [] = Logger.get_module_level(Enum)
    end
  end

  describe "clear_module_level/1" do
    test "clears an applied module-level override" do
      assert {:ok, _overrides} = RuntimeLogOverrides.set_module_level("Enum", :debug)

      assert {:ok, overrides} = RuntimeLogOverrides.clear_module_level("Enum")

      assert [] = overrides.modules
      assert [] = Logger.get_module_level(Enum)
    end

    test "rejects clearing an invalid module" do
      assert {:error, :invalid_module} = RuntimeLogOverrides.clear_module_level("Not.A.Module")
    end
  end

  describe "cluster-wide operations" do
    test "applies a system-level override across all reachable nodes" do
      nodes = [:node_a@cluster, :node_b@cluster]

      put_rpc_response(:node_a@cluster, :apply_system_level_local, [:warning], %{
        node: :node_a@cluster,
        system_level: :warning,
        module_levels: %{}
      })

      put_rpc_response(:node_b@cluster, :apply_system_level_local, [:warning], %{
        node: :node_b@cluster,
        system_level: :warning,
        module_levels: %{}
      })

      put_uniform_cluster_state(nodes, system_level: :warning, module_levels: %{})

      assert {:ok, result} =
               RuntimeLogOverrides.cluster_apply_system_level(:warning,
                 nodes: nodes,
                 rpc_module: FakeRPC
               )

      assert result.status == :success
      assert result.successful_nodes == nodes
      assert result.failed_nodes == []

      assert result.cluster_state.system_level == %{
               status: :uniform,
               level: :warning,
               exceptions: []
             }
    end

    test "clears a system-level override across all reachable nodes" do
      nodes = [:node_a@cluster, :node_b@cluster]
      configured_level = Application.get_env(:logger, :level)

      put_rpc_response(:node_a@cluster, :clear_system_level_local, [], %{
        node: :node_a@cluster,
        system_level: configured_level,
        module_levels: %{}
      })

      put_rpc_response(:node_b@cluster, :clear_system_level_local, [], %{
        node: :node_b@cluster,
        system_level: configured_level,
        module_levels: %{}
      })

      put_uniform_cluster_state(nodes, system_level: configured_level, module_levels: %{})

      assert {:ok, result} =
               RuntimeLogOverrides.cluster_clear_system_level(nodes: nodes, rpc_module: FakeRPC)

      assert result.status == :success
      assert result.cluster_state.system_level.level == configured_level
    end

    test "applies and clears a module-level override across all reachable nodes" do
      nodes = [:node_a@cluster, :node_b@cluster]

      put_rpc_response(:node_a@cluster, :apply_module_level_local, [Enum, :debug], %{
        node: :node_a@cluster,
        system_level: :warning,
        module_levels: %{Enum => :debug}
      })

      put_rpc_response(:node_b@cluster, :apply_module_level_local, [Enum, :debug], %{
        node: :node_b@cluster,
        system_level: :warning,
        module_levels: %{Enum => :debug}
      })

      put_uniform_cluster_state(nodes, system_level: :warning, module_levels: %{Enum => :debug})

      assert {:ok, apply_result} =
               RuntimeLogOverrides.cluster_apply_module_level("Enum", :debug,
                 nodes: nodes,
                 rpc_module: FakeRPC
               )

      assert apply_result.status == :success

      assert [%{module: Enum, status: :uniform, level: :debug}] =
               Enum.map(
                 apply_result.cluster_state.module_levels,
                 &Map.take(&1, [:module, :status, :level])
               )

      put_rpc_response(:node_a@cluster, :clear_module_level_local, [Enum], %{
        node: :node_a@cluster,
        system_level: :warning,
        module_levels: %{}
      })

      put_rpc_response(:node_b@cluster, :clear_module_level_local, [Enum], %{
        node: :node_b@cluster,
        system_level: :warning,
        module_levels: %{}
      })

      put_uniform_cluster_state(nodes, system_level: :warning, module_levels: %{})

      assert {:ok, clear_result} =
               RuntimeLogOverrides.cluster_clear_module_level("Enum",
                 nodes: nodes,
                 rpc_module: FakeRPC
               )

      assert clear_result.status == :success
      assert clear_result.cluster_state.module_levels == []
    end

    test "reports partial success when one node fails during a module override" do
      nodes = [:node_a@cluster, :node_b@cluster]

      put_rpc_response(:node_a@cluster, :apply_module_level_local, [Enum, :debug], %{
        node: :node_a@cluster,
        system_level: :warning,
        module_levels: %{Enum => :debug}
      })

      put_rpc_response(
        :node_b@cluster,
        :apply_module_level_local,
        [Enum, :debug],
        {:raise, RuntimeError.exception("node unavailable")}
      )

      put_rpc_response(:node_a@cluster, :local_state, [], %{
        node: :node_a@cluster,
        system_level: :warning,
        module_levels: %{Enum => :debug}
      })

      put_rpc_response(
        :node_b@cluster,
        :local_state,
        [],
        {:raise, RuntimeError.exception("state unavailable")}
      )

      assert {:error, result} =
               RuntimeLogOverrides.cluster_apply_module_level("Enum", :debug,
                 nodes: nodes,
                 rpc_module: FakeRPC
               )

      assert result.status == :partial
      assert result.successful_nodes == [:node_a@cluster]
      assert [%{node: :node_b@cluster, reason: reason}] = result.failed_nodes
      assert reason =~ "node unavailable"
      assert result.cluster_state.status == :partial
      assert [%{node: :node_b@cluster, reason: state_reason}] = result.cluster_state.read_errors
      assert state_reason =~ "state unavailable"
    end

    test "reports failure when every target node is unreachable" do
      nodes = [:node_a@cluster, :node_b@cluster]

      put_rpc_response(:node_a@cluster, :apply_system_level_local, [:error], {:exit, :nodedown})
      put_rpc_response(:node_b@cluster, :apply_system_level_local, [:error], {:exit, :nodedown})
      put_rpc_response(:node_a@cluster, :local_state, [], {:exit, :nodedown})
      put_rpc_response(:node_b@cluster, :local_state, [], {:exit, :nodedown})

      assert {:error, result} =
               RuntimeLogOverrides.cluster_apply_system_level(:error,
                 nodes: nodes,
                 rpc_module: FakeRPC
               )

      assert result.status == :failure
      assert result.successful_nodes == []
      assert Enum.all?(result.failed_nodes, &(&1.reason =~ "nodedown"))
      assert result.cluster_state.status == :failure
    end

    test "rejects invalid cluster inputs before fan-out" do
      assert {:error, :invalid_level} =
               RuntimeLogOverrides.cluster_apply_system_level("verbose", rpc_module: FakeRPC)

      assert {:error, :invalid_module} =
               RuntimeLogOverrides.cluster_apply_module_level("Not.A.Real.Module", :debug,
                 rpc_module: FakeRPC
               )
    end

    test "summarizes mixed cluster state" do
      nodes = [:node_a@cluster, :node_b@cluster]

      put_rpc_response(:node_a@cluster, :local_state, [], %{
        node: :node_a@cluster,
        system_level: :warning,
        module_levels: %{Enum => :debug}
      })

      put_rpc_response(:node_b@cluster, :local_state, [], %{
        node: :node_b@cluster,
        system_level: :error,
        module_levels: %{}
      })

      state = RuntimeLogOverrides.cluster_state(nodes: nodes, rpc_module: FakeRPC)

      assert state.status == :success
      assert state.system_level.status == :mixed
      assert state.system_level.level == nil

      assert [
               %{
                 module: Enum,
                 status: :mixed,
                 level: nil,
                 exceptions: [
                   %{node: :node_a@cluster, level: :debug},
                   %{node: :node_b@cluster, level: nil}
                 ]
               }
             ] =
               Enum.map(
                 state.module_levels,
                 &Map.take(&1, [:module, :status, :level, :exceptions])
               )
    end

    test "emits telemetry for cluster operations" do
      nodes = [:node_a@cluster, :node_b@cluster]
      handler_id = "runtime-log-overrides-telemetry-#{System.unique_integer([:positive])}"
      parent = self()

      :telemetry.attach(
        handler_id,
        [:oli, :runtime_log_overrides, :cluster_operation],
        fn event_name, measurements, metadata, _config ->
          send(parent, {:telemetry_event, event_name, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      put_rpc_response(:node_a@cluster, :apply_system_level_local, [:warning], %{
        node: :node_a@cluster,
        system_level: :warning,
        module_levels: %{}
      })

      put_rpc_response(:node_b@cluster, :apply_system_level_local, [:warning], %{
        node: :node_b@cluster,
        system_level: :warning,
        module_levels: %{}
      })

      put_uniform_cluster_state(nodes, system_level: :warning, module_levels: %{})

      assert {:ok, _result} =
               RuntimeLogOverrides.cluster_apply_system_level(:warning,
                 nodes: nodes,
                 rpc_module: FakeRPC
               )

      assert_receive {:telemetry_event, [:oli, :runtime_log_overrides, :cluster_operation],
                      %{duration: duration}, metadata}

      assert duration >= 0
      assert metadata.operation == :apply_system
      assert metadata.target_node_count == 2
      assert metadata.success_count == 2
      assert metadata.failure_count == 0
      assert metadata.status == :success
      assert metadata.requested_level == :warning
    end
  end

  defp put_uniform_cluster_state(nodes, system_level: system_level, module_levels: module_levels) do
    Enum.each(nodes, fn node ->
      put_rpc_response(node, :local_state, [], %{
        node: node,
        system_level: system_level,
        module_levels: module_levels
      })
    end)
  end

  defp put_rpc_response(node, function, args, response) do
    Agent.update(FakeRPC.Store, &Map.put(&1, {node, function, args}, response))
  end

  defp ensure_registry_started do
    case Process.whereis(Registry) do
      nil -> start_supervised!({Registry, []})
      _pid -> :ok
    end
  end

  defp ensure_fake_rpc_store_started do
    case Process.whereis(FakeRPC.Store) do
      nil -> {:ok, _pid} = Agent.start_link(fn -> %{} end, name: FakeRPC.Store)
      _pid -> :ok
    end
  end
end
