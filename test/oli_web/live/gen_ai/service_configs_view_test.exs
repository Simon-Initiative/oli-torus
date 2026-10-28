# Acceptance coverage: AC-018.
defmodule OliWeb.GenAI.ServiceConfigsViewTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Ecto.Query

  alias Oli.GenAI
  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}
  alias Oli.Repo

  @route Routes.live_path(OliWeb.Endpoint, OliWeb.GenAI.ServiceConfigsView)

  describe "admins can edit service config parameters" do
    setup [:admin_conn, :create_service_config]

    test "renders routing health section", %{conn: conn} do
      {:ok, _view, html} = live(conn, @route)

      assert html =~ "Routing Health"
      assert html =~ "Maximum checked-out connections"
      refute html =~ "Breaker"
      refute html =~ "Latency p95"
    end

    test "empty configuration lists mount and deleting the last configuration stays usable", %{
      conn: conn,
      service_config: config
    } do
      Repo.delete_all(Oli.GenAI.FeatureConfig)
      Repo.delete_all(from c in ServiceConfig, where: c.id != ^config.id)
      {:ok, view, _} = live(conn, @route)
      view |> element("form#toggle_editing") |> render_change(%{"toggle_editing" => "on"})
      html = render_click(view, "delete", %{"id" => to_string(config.id)})
      assert html =~ "No service configurations yet"
      {:ok, _new_view, html} = live(conn, @route)
      assert html =~ "No service configurations yet"
    end

    test "configuration tests report asynchronously without rendering raw content", %{
      conn: conn,
      service_config: config
    } do
      loaded = Oli.GenAI.Configuration.runtime_configuration(reconcile_probes: false)
      manager = start_supervised!({Oli.GenAI.PoolManager, name: nil, namespace: make_ref()})
      tasks = start_supervised!({Task.Supervisor, max_children: 1})

      start_supervised!(
        {Oli.GenAI.Runtime,
         source: fn -> loaded end, pool_manager: manager, task_supervisor: tasks, enabled: false}
      )

      assert :ok = Oli.GenAI.Runtime.reconcile()
      {:ok, view, _} = live(conn, @route)
      render_click(view, "select", %{"id" => to_string(config.id)})
      render_click(view, "test")
      html = render_async(view)
      assert html =~ "Test successful"
      refute html =~ "No generation performed"
    end

    test "updates service config fields", %{conn: conn, service_config: service_config} do
      {:ok, view, _html} = live(conn, @route)

      render_click(view, "select", %{"id" => to_string(service_config.id)})

      view
      |> element("form#toggle_editing")
      |> render_change(%{"toggle_editing" => "on"})

      params = %{
        "name" => service_config.name,
        "primary_model_id" => to_string(service_config.primary_model_id),
        "secondary_model_id" => to_string(service_config.secondary_model_id),
        "backup_model_id" => "",
        "primary_pool_capacity" => "7",
        "secondary_pool_capacity" => "9",
        "backup_pool_capacity" => "3"
      }

      view
      |> form("#service-config-form", service_config: params)
      |> render_submit()
      |> then(fn html ->
        refute html =~ "Couldn't update service config"
        html
      end)

      updated = Repo.get!(ServiceConfig, service_config.id)
      assert updated.secondary_model_id == service_config.secondary_model_id
      assert updated.primary_pool_capacity == 7 and updated.secondary_pool_capacity == 9
    end
  end

  defp create_service_config(_context) do
    {:ok, provider} = GenAI.create_provider(%{name: "Test local Provider", adapter: :null})

    model =
      Repo.insert!(%RegisteredModel{
        name: "Test Model",
        provider_id: provider.id,
        model: "null",
        timeout: 8000,
        recv_timeout: 60_000
      })

    secondary_model =
      Repo.insert!(%RegisteredModel{
        name: "Secondary Model",
        provider_id: provider.id,
        model: "null-secondary",
        timeout: 8000,
        recv_timeout: 60_000
      })

    {:ok, service_config} =
      GenAI.create_service_config(%{
        name: "Test Service Config",
        primary_model_id: model.id,
        secondary_model_id: secondary_model.id,
        backup_model_id: nil
      })

    {:ok, service_config: service_config}
  end
end
