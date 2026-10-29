# Acceptance coverage: AC-001, AC-018.
defmodule OliWeb.GenAI.ProvidersViewTest do
  use OliWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Oli.GenAI
  @route "/admin/gen_ai/providers"

  describe "Provider administration (AC-001, AC-018)" do
    setup [:admin_conn]

    test "saves credentials without echoing stored or submitted keys", %{conn: conn} do
      {:ok, provider} =
        GenAI.create_provider(%{
          name: "Secret Provider",
          adapter: :open_ai,
          base_url: "https://provider.example",
          api_key: "stored-private-key"
        })

      {:ok, view, html} = live(conn, @route)
      refute html =~ "stored-private-key"
      render_click(view, "select", %{"id" => to_string(provider.id)})
      view |> element("form#toggle_editing") |> render_change(%{"toggle_editing" => "on"})

      html =
        view
        |> form("#provider-form",
          provider: %{
            name: "Renamed Provider",
            base_url: "https://provider.example",
            api_key: "rotated-private-key",
            organization_key: "private-org",
            failure_threshold: "4",
            enabled: "true"
          }
        )
        |> render_submit()

      refute html =~ "rotated-private-key"
      refute html =~ "private-org"
      updated = Enum.find(GenAI.providers(), &(&1.id == provider.id))
      assert updated.api_key == "rotated-private-key" and updated.failure_threshold == 4
      view |> element("form#toggle_editing") |> render_change(%{"toggle_editing" => "on"})

      view
      |> form("#provider-form",
        provider: %{name: "Retained key", api_key: "", organization_key: ""}
      )
      |> render_submit()

      assert Enum.find(GenAI.providers(), &(&1.id == provider.id)).api_key ==
               "rotated-private-key"
    end

    test "renders disabled, unknown, stale and missing-model diagnostics accessibly", _ do
      provider = %Oli.GenAI.Provider{id: 88, name: "Display Provider"}

      base = %{
        administrative_enabled: true,
        monitoring_enabled: true,
        observed: :unknown,
        health_check_model_id: nil,
        last_check: nil,
        last_success: nil,
        next_check: nil,
        consecutive_failures: 0,
        consecutive_successes: 0,
        failure_category: nil
      }

      for {overrides, expected} <- [
            {%{}, "Unknown"},
            {%{observed: :stale}, "Stale"},
            {%{observed: :unavailable}, "Unavailable"},
            {%{monitoring_enabled: false}, "Health checks disabled"},
            {%{administrative_enabled: false}, "Administratively disabled"},
            {%{failure_category: :missing_probe_model}, "missing_probe_model"}
          ] do
        health = Map.merge(base, overrides)

        html =
          render_component(&OliWeb.GenAI.ProvidersView.render/1,
            providers: [provider],
            selected: provider,
            model_names: %{},
            editing: false,
            diagnostics: %{health: %{error: nil, providers: %{88 => health}}},
            form: Phoenix.Component.to_form(Ecto.Changeset.change(provider), as: :provider)
          )

        assert html =~ expected
        assert html =~ "Selected health-check model"
        document = Floki.parse_document!(html)
        assert Floki.attribute(document, "#toggle_editing_checkbox", "type") == ["checkbox"]
        assert Floki.attribute(document, "#toggle_editing_checkbox", "checked") == []
        assert html =~ ~s(autocomplete="new-password")
        assert html =~ ~s(for="provider_api_key")
      end
    end

    test "invalid submitted secrets are never reflected and server rejects writes while locked",
         %{conn: conn} do
      {:ok, view, _} = live(conn, @route)
      assert render_click(view, "save", %{"provider" => %{}}) =~ "Enable editing first"
      view |> element("form#toggle_editing") |> render_change(%{"toggle_editing" => "on"})
      render_click(view, "new")

      html =
        view
        |> form("#provider-form",
          provider: %{
            name: "",
            adapter: "open_ai",
            base_url: "invalid",
            api_key: "invalid-private-key"
          }
        )
        |> render_submit()

      refute html =~ "invalid-private-key"
      assert html =~ "must be an HTTP"
    end

    test "creates, disables and deletes an unused Provider", %{conn: conn} do
      {:ok, view, _} = live(conn, @route)
      view |> element("form#toggle_editing") |> render_change(%{"toggle_editing" => "on"})
      render_click(view, "new")

      view
      |> form("#provider-form",
        provider: %{name: "New local Provider", adapter: "null", enabled: "false"}
      )
      |> render_submit()

      provider = Enum.find(GenAI.providers(), &(&1.name == "New local Provider"))
      refute provider.enabled
      view |> element("form#toggle_editing") |> render_change(%{"toggle_editing" => "on"})
      render_click(view, "delete")
      refute Enum.any?(GenAI.providers(), &(&1.id == provider.id))
    end
  end

  describe "authorization" do
    setup [:author_conn]

    test "ordinary authors cannot access any GenAI administration", %{conn: conn} do
      for route <- [@route, "/admin/gen_ai/registered_models", "/admin/gen_ai/service_configs"] do
        assert {:error, {:redirect, _}} = live(conn, route)
      end
    end
  end
end
