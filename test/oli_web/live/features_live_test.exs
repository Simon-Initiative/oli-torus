defmodule OliWeb.FeaturesLiveTest do
  use ExUnit.Case, async: false
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

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

  defp live_view_route, do: ~p"/admin/features"

  setup do
    ensure_fake_rpc_store_started()

    original_level = Logger.level()
    original_env = Application.get_env(:oli, :runtime_log_overrides)

    Logger.delete_all_module_levels()
    Registry.reset()
    Agent.update(FakeRPC.Store, fn _ -> %{} end)

    on_exit(fn ->
      Logger.delete_all_module_levels()
      Registry.reset()
      Logger.configure(level: original_level)

      case original_env do
        nil -> Application.delete_env(:oli, :runtime_log_overrides)
        value -> Application.put_env(:oli, :runtime_log_overrides, value)
      end
    end)

    :ok
  end

  describe "authorization" do
    setup [:author_conn]

    test "redirects non-admin authors away from the page", %{conn: conn} do
      conn = get(conn, live_view_route())

      assert redirected_to(conn, 302) == "/workspaces/course_author"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "You are not authorized to access this page."
    end
  end

  describe "cluster runtime override UI" do
    setup [:admin_conn]

    test "renders cluster-scoped copy and empty state", %{conn: conn} do
      nodes = [:node_a@cluster, :node_b@cluster]
      put_uniform_cluster_state(nodes, system_level: :warning, module_levels: %{})

      {:ok, view, _html} = live(conn, live_view_route())

      assert render(view) =~ "Actions on this page target all currently connected Torus nodes"
      assert render(view) =~ "runtime-only"
      assert render(view) =~ "Current cluster system log level: warning"
      assert has_element?(view, "#clear-system-log-level", "Clear Cluster Override")

      assert has_element?(
               view,
               "#no-module-log-overrides",
               "No active module overrides across the connected cluster."
             )
    end

    test "renders mixed cluster state and read failures", %{conn: conn} do
      nodes = [:node_a@cluster, :node_b@cluster, :node_c@cluster]

      configure_runtime_log_overrides(nodes)

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

      put_rpc_response(:node_c@cluster, :local_state, [], {:exit, :nodedown})

      {:ok, view, _html} = live(conn, live_view_route())

      assert render(view) =~ "Current cluster system log level is mixed"
      assert render(view) =~ "Mixed override state across connected nodes."
      assert render(view) =~ "Cluster state could not be read from: node_c@cluster"
      assert render(view) =~ "node_a@cluster: debug"
      assert render(view) =~ "node_b@cluster: none"
    end

    test "applies a module override and renders cluster success", %{conn: conn} do
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

      {:ok, view, _html} = live(conn, live_view_route())

      view
      |> element("#module-log-override-form")
      |> render_submit(%{
        "module_override" => %{"module_name" => "Enum", "level" => "debug"}
      })

      assert render(view) =~
               "Applied cluster module override for Enum at debug across 2 connected nodes."

      assert has_element?(view, "#active-module-log-overrides")
      assert has_element?(view, "#module-log-override-Elixir-Enum", "Elixir.Enum")
      refute render(view) =~ "No active module overrides across the connected cluster."
    end

    test "shows partial-failure feedback with failed node details", %{conn: conn} do
      nodes = [:node_a@cluster, :node_b@cluster]
      configure_runtime_log_overrides(nodes)

      put_rpc_response(:node_a@cluster, :clear_system_level_local, [], %{
        node: :node_a@cluster,
        system_level: :warning,
        module_levels: %{}
      })

      put_rpc_response(
        :node_b@cluster,
        :clear_system_level_local,
        [],
        {:raise, RuntimeError.exception("node unavailable")}
      )

      put_rpc_response(:node_a@cluster, :local_state, [], %{
        node: :node_a@cluster,
        system_level: :warning,
        module_levels: %{}
      })

      put_rpc_response(
        :node_b@cluster,
        :local_state,
        [],
        {:raise, RuntimeError.exception("state unavailable")}
      )

      {:ok, view, _html} = live(conn, live_view_route())

      view
      |> element("#clear-system-log-level")
      |> render_click()

      assert render(view) =~ "Partial success while trying to clear cluster system log override."
      assert render(view) =~ "Failed or unreachable nodes: node_b@cluster."
    end

    test "shows an error for an invalid module", %{conn: conn} do
      nodes = [:node_a@cluster, :node_b@cluster]
      put_uniform_cluster_state(nodes, system_level: :warning, module_levels: %{})

      {:ok, view, _html} = live(conn, live_view_route())

      view
      |> element("#module-log-override-form")
      |> render_submit(%{
        "module_override" => %{"module_name" => "Not.A.Real.Module", "level" => "debug"}
      })

      assert render(view) =~ "Module log override failed: invalid module"
      assert has_element?(view, "#no-module-log-overrides")
    end

    test "delegates the system logging action to the backend boundary instead of mutating local logger state",
         %{
           conn: conn
         } do
      nodes = [:node_a@cluster, :node_b@cluster]

      Logger.configure(level: :warning)

      put_rpc_response(:node_a@cluster, :apply_system_level_local, [:error], %{
        node: :node_a@cluster,
        system_level: :error,
        module_levels: %{}
      })

      put_rpc_response(:node_b@cluster, :apply_system_level_local, [:error], %{
        node: :node_b@cluster,
        system_level: :error,
        module_levels: %{}
      })

      put_uniform_cluster_state(nodes, system_level: :error, module_levels: %{})

      {:ok, view, _html} = live(conn, live_view_route())

      view
      |> element("button[phx-click='logging'][phx-value-level='error']")
      |> render_click()

      assert render(view) =~ "Applied cluster system log level error across 2 connected nodes."
      assert Logger.level() == :warning
    end
  end

  defp put_uniform_cluster_state(nodes, system_level: system_level, module_levels: module_levels) do
    configure_runtime_log_overrides(nodes)

    Enum.each(nodes, fn node ->
      put_rpc_response(node, :local_state, [], %{
        node: node,
        system_level: system_level,
        module_levels: module_levels
      })
    end)
  end

  defp configure_runtime_log_overrides(nodes) do
    Application.put_env(:oli, :runtime_log_overrides, nodes: nodes, rpc_module: FakeRPC)
  end

  defp put_rpc_response(node, function, args, response) do
    Agent.update(FakeRPC.Store, &Map.put(&1, {node, function, args}, response))
  end

  defp ensure_fake_rpc_store_started do
    case Process.whereis(FakeRPC.Store) do
      nil -> {:ok, _pid} = Agent.start_link(fn -> %{} end, name: FakeRPC.Store)
      _pid -> :ok
    end
  end
end
