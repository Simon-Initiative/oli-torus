defmodule OliWeb.GenAI.ServiceConfigsViewTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.GenAI
  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}
  alias Oli.Repo

  @route Routes.live_path(OliWeb.Endpoint, OliWeb.GenAI.ServiceConfigsView)

  describe "admins can edit routing policy parameters" do
    setup [:admin_conn, :create_service_config]

    test "renders routing policy and health sections", %{conn: conn} do
      {:ok, _view, html} = live(conn, @route)

      assert html =~ "Routing Policy"
      assert html =~ "Routing Health"
    end

    test "updates routing policy fields", %{conn: conn, service_config: service_config} do
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
        "routing_soft_limit" => "10",
        "routing_hard_limit" => "20",
        "routing_stream_soft_limit" => "4",
        "routing_stream_hard_limit" => "8",
        "routing_breaker_error_rate_threshold" => "0.2",
        "routing_breaker_429_threshold" => "0.1",
        "routing_breaker_latency_p95_ms" => "6000",
        "routing_open_cooldown_ms" => "30000",
        "routing_half_open_probe_count" => "3",
        "routing_timeout_ms" => "30000",
        "routing_connect_timeout_ms" => "5000"
      }

      view
      |> form("#service-config-form", service_config: params)
      |> render_submit()
      |> then(fn html -> refute html =~ "Couldn't update service config"; html end)

      updated = Repo.get!(ServiceConfig, service_config.id)
      assert updated.routing_soft_limit == 10
      assert updated.routing_hard_limit == 20
      assert updated.routing_stream_soft_limit == 4
      assert updated.routing_stream_hard_limit == 8
      assert updated.secondary_model_id == service_config.secondary_model_id
    end
  end

  defp create_service_config(_context) do
    model =
      Repo.insert!(%RegisteredModel{
        name: "Test Model",
        provider: :null,
        model: "null",
        url_template: "http://localhost",
        api_key: "secret",
        timeout: 8000,
        recv_timeout: 60_000
      })

    secondary_model =
      Repo.insert!(%RegisteredModel{
        name: "Secondary Model",
        provider: :null,
        model: "null-secondary",
        url_template: "http://localhost",
        api_key: "secret",
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
