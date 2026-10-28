# Acceptance coverage: AC-018.
defmodule OliWeb.GenAI.RegisteredModelsViewTest do
  use OliWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Oli.GenAI
  alias Oli.GenAI.Completions.RegisteredModel
  @route "/admin/gen_ai/registered_models"

  describe "authorized model administration (AC-003, AC-018, AC-021)" do
    setup [:admin_conn]

    test "edits Provider membership, designation and timeouts without legacy controls", %{
      conn: conn
    } do
      {:ok, provider} = GenAI.create_provider(%{name: "Local test", adapter: :null})

      {:ok, model} =
        GenAI.create_registered_model(%{
          name: "Local model",
          model: "null",
          provider_id: provider.id
        })

      {:ok, view, html} = live(conn, @route)
      refute html =~ "Breaker"
      refute html =~ "Max Concurrent"
      refute html =~ "Fast Pool"
      refute html =~ "API Key"
      render_click(view, "select_model", %{"id" => to_string(model.id)})
      render_click(view, "toggle_editing")

      view
      |> form("#registered-model-form",
        registered_model: %{
          name: "Edited",
          model: "null-next",
          provider_id: provider.id,
          health_check: "true",
          timeout: "9000",
          recv_timeout: "120000",
          capabilities_text: "chat, tools"
        }
      )
      |> render_submit()

      updated = Oli.Repo.get!(RegisteredModel, model.id)
      assert updated.name == "Edited" and updated.health_check
      assert updated.timeout == 9000 and updated.recv_timeout == 120_000
      assert updated.capabilities == ["chat", "tools"]
    end

    test "dependent configuration errors preserve model form and identify the blocked relationship",
         %{conn: conn} do
      {:ok, provider} = GenAI.create_provider(%{name: "Main", adapter: :null})
      {:ok, other} = GenAI.create_provider(%{name: "Other", adapter: :null})

      {:ok, primary} =
        GenAI.create_registered_model(%{
          name: "Primary",
          model: "p",
          provider_id: provider.id,
          capabilities: ["chat"]
        })

      {:ok, secondary} =
        GenAI.create_registered_model(%{
          name: "Secondary",
          model: "s",
          provider_id: provider.id,
          capabilities: ["chat"]
        })

      {:ok, _} =
        GenAI.create_service_config(%{
          name: "Dependent config",
          primary_model_id: primary.id,
          secondary_model_id: secondary.id,
          required_capabilities: ["chat"]
        })

      {:ok, view, _} = live(conn, @route)
      render_click(view, "select_model", %{"id" => to_string(secondary.id)})
      render_click(view, "toggle_editing")

      html =
        view
        |> form("#registered-model-form",
          registered_model: %{
            name: "Secondary",
            model: "s",
            provider_id: other.id,
            capabilities_text: "chat"
          }
        )
        |> render_submit()

      assert html =~ "Dependent config"
      assert has_element?(view, "#registered_model_name[value=Secondary]")
      assert Oli.Repo.get!(RegisteredModel, secondary.id).provider_id == provider.id

      html =
        view
        |> form("#registered-model-form",
          registered_model: %{
            name: "Secondary",
            model: "s",
            provider_id: provider.id,
            capabilities_text: ""
          }
        )
        |> render_submit()

      assert html =~ "required capabilities"
      assert Oli.Repo.get!(RegisteredModel, secondary.id).capabilities == ["chat"]
      assert render_click(view, "delete") =~ "Model is referenced"
      assert Oli.Repo.get!(RegisteredModel, secondary.id)
    end

    test "model transport settings follow the selected Provider", %{conn: conn} do
      {:ok, provider} = GenAI.create_provider(%{name: "Local", adapter: :null})

      {:ok, other} =
        GenAI.create_provider(%{
          name: "Remote",
          adapter: :open_ai,
          base_url: "https://example.test",
          api_key: "dummy-key"
        })

      {:ok, model} =
        GenAI.create_registered_model(%{
          name: "Local model",
          model: "null",
          provider_id: provider.id
        })

      {:ok, view, _} = live(conn, @route)
      render_click(view, "select_model", %{"id" => to_string(model.id)})
      render_click(view, "toggle_editing")

      html =
        view
        |> form("#registered-model-form", registered_model: %{provider_id: other.id})
        |> render_submit()

      refute html =~ "Changing transport adapter requires a new model"
      assert Oli.Repo.get!(RegisteredModel, model.id).provider_id == other.id
    end

    test "model tests run asynchronously and show only a safe result", %{conn: conn} do
      {:ok, provider} = GenAI.create_provider(%{name: "Local diagnostics", adapter: :null})

      {:ok, model} =
        GenAI.create_registered_model(%{
          name: "Diagnostic model",
          model: "null",
          provider_id: provider.id
        })

      loaded = Oli.GenAI.Configuration.runtime_configuration(reconcile_probes: false)
      manager = start_supervised!({Oli.GenAI.PoolManager, namespace: make_ref(), poll_ms: 10})
      tasks = start_supervised!({Task.Supervisor, max_children: 2})

      runtime =
        start_supervised!(
          {Oli.GenAI.Runtime,
           source: fn -> loaded end,
           enabled: false,
           pool_manager: manager,
           task_supervisor: tasks,
           probe: fn _, _ -> :ok end}
        )

      assert :ok = Oli.GenAI.Runtime.reconcile(runtime)
      {:ok, view, _} = live(conn, @route)
      render_click(view, "select_model", %{"id" => to_string(model.id)})
      render_click(view, "test")
      html = render_async(view)
      assert html =~ "Test successful"
      refute html =~ "No generation performed"
    end

    test "server enforces edit mode and handles new unsaved models", %{conn: conn} do
      {:ok, view, _} = live(conn, @route)
      assert render_click(view, "save", %{"registered_model" => %{}}) =~ "Enable editing first"
      render_click(view, "toggle_editing")
      assert render_click(view, "new_model") =~ "Select a Provider"
    end
  end
end
