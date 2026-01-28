defmodule OliWeb.GenAI.RegisteredModelsViewTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.GenAI.Completions.RegisteredModel
  alias Oli.GenAI.HackneyPool
  alias Oli.Repo

  @route Routes.live_path(OliWeb.Endpoint, OliWeb.GenAI.RegisteredModelsView)

  describe "admins can manage registered models and pool sizes" do
    setup [:admin_conn, :create_registered_model]

    test "updates pool sizes via admin form", %{conn: conn} do
      fast_size = HackneyPool.max_connections(:fast)
      slow_size = HackneyPool.max_connections(:slow)

      on_exit(fn ->
        HackneyPool.set_max_connections(:fast, fast_size)
        HackneyPool.set_max_connections(:slow, slow_size)
      end)

      {:ok, view, _html} = live(conn, @route)

      view
      |> element("form#toggle_editing")
      |> render_change(%{"toggle_editing" => "on"})

      view
      |> form("#pool-sizes-form",
        pool_sizes: %{"fast_pool_size" => "12", "slow_pool_size" => "34"}
      )
      |> render_submit()
      |> then(fn html ->
        assert html =~ "Updated GenAI pool sizes"
        html
      end)
    end

    test "rejects pool sizes above configured max", %{conn: conn} do
      previous = Application.get_env(:oli, :genai_hackney_pool_max_size, 1000)

      Application.put_env(:oli, :genai_hackney_pool_max_size, 10)

      on_exit(fn ->
        Application.put_env(:oli, :genai_hackney_pool_max_size, previous)
      end)

      {:ok, view, _html} = live(conn, @route)

      view
      |> element("form#toggle_editing")
      |> render_change(%{"toggle_editing" => "on"})

      view
      |> form("#pool-sizes-form",
        pool_sizes: %{"fast_pool_size" => "11", "slow_pool_size" => "10"}
      )
      |> render_submit()
      |> then(fn html ->
        assert html =~ "Pool size for fast must be &lt;= 10"
        html
      end)
    end

    test "updates pool class and max concurrent values", %{
      conn: conn,
      registered_model: registered_model
    } do
      {:ok, view, _html} = live(conn, @route)

      render_click(view, "select_model", %{"id" => to_string(registered_model.id)})

      view
      |> element("form#toggle_editing")
      |> render_change(%{"toggle_editing" => "on"})

      params = %{
        "name" => registered_model.name,
        "provider" => "open_ai",
        "model" => registered_model.model,
        "pool_class" => "fast",
        "max_concurrent" => "25",
        "routing_breaker_error_rate_threshold" => "0.25",
        "routing_breaker_429_threshold" => "0.15",
        "routing_breaker_latency_p95_ms" => "6500",
        "routing_open_cooldown_ms" => "40000",
        "routing_half_open_probe_count" => "4",
        "url_template" => registered_model.url_template,
        "api_key" => "secret",
        "secondary_api_key" => "secret",
        "timeout" => "8000",
        "recv_timeout" => "60000"
      }

      view
      |> form("#registered-model-form", registered_model: params)
      |> render_submit()
      |> then(fn html ->
        refute html =~ "Couldn't update registered model"
        html
      end)

      updated = Repo.get!(RegisteredModel, registered_model.id)
      assert updated.pool_class == :fast
      assert updated.max_concurrent == 25
      assert updated.routing_breaker_error_rate_threshold == 0.25
      assert updated.routing_breaker_429_threshold == 0.15
      assert updated.routing_breaker_latency_p95_ms == 6500
      assert updated.routing_open_cooldown_ms == 40_000
      assert updated.routing_half_open_probe_count == 4
    end
  end

  defp create_registered_model(_context) do
    registered_model =
      Repo.insert!(%RegisteredModel{
        name: "Test Model",
        provider: :open_ai,
        model: "gpt-4-test",
        url_template: "http://localhost",
        api_key: "secret",
        secondary_api_key: "secret",
        timeout: 8000,
        recv_timeout: 60_000
      })

    {:ok, registered_model: registered_model}
  end
end
