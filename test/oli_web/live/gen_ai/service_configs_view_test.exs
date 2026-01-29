defmodule OliWeb.GenAI.ServiceConfigsViewTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.GenAI
  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}
  alias Oli.Repo

  @route Routes.live_path(OliWeb.Endpoint, OliWeb.GenAI.ServiceConfigsView)

  describe "admins can edit service config parameters" do
    setup [:admin_conn, :create_service_config]

    test "renders routing health section", %{conn: conn} do
      {:ok, _view, html} = live(conn, @route)

      assert html =~ "Routing Health"
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
        "backup_model_id" => ""
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
