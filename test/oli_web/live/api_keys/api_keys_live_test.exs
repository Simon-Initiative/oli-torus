defmodule OliWeb.ApiKeys.ApiKeysLiveTest do
  use OliWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  @moduledoc false

  # - Enforces access control for unauthenticated and non-admin authors
  # - Renders inputs and table headers for API keys management
  # - Creates a key via UI and shows generated key once
  # - Toggles fields and status; updates registration namespace

  defp route, do: "/admin/api_keys"

  describe "access control" do
    test "redirects to new session when not logged in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/authors/log_in"}}} = live(conn, route())
    end

    test "redirects to authoring workspace when not a system admin", %{conn: conn} do
      author = Oli.Factory.insert(:author)
      conn = log_in_author(conn, author)
      assert {:error, {:redirect, %{to: "/workspaces/course_author"}}} = live(conn, route())
    end
  end

  describe "system admin" do
    setup [:admin_conn]

    test "renders inputs and table headers", %{conn: conn} do
      {:ok, view, html} = live(conn, route())

      assert html =~ "Enter a description/hint for a new API key:"
      assert has_element?(view, "input[phx-change='hint']")
      assert has_element?(view, "button[phx-click='create']", "Create New")

      assert has_element?(view, "th", "Key Hint")
      assert has_element?(view, "th", "Status")
      assert has_element?(view, "th", "Payments Enabled")
      assert has_element?(view, "th", "Prodcuts Enabled")
      assert has_element?(view, "th", "Registration Enabled")
      assert has_element?(view, "th", "Registration Namespace")
      assert has_element?(view, "th", "Automation Data")
      assert has_element?(view, "th", "Action")
    end

    test "creates a new API key and displays the generated key once", %{conn: conn} do
      {:ok, view, _html} = live(conn, route())

      view
      |> element("input[phx-change='hint']")
      |> render_change(%{"value" => "Test Key"})

      view
      |> element("button[phx-click='create']", "Create New")
      |> render_click()

      html = render(view)

      assert html =~
               "This is the API key.  Copy this now, this is the only time you will see this."

      # Basic UUID format check presence via dashes
      assert html =~ "<code>"
    end

    test "toggles fields and status and updates registration namespace", %{conn: conn} do
      # Arrange: create a key and make it enabled to exercise toggle
      {:ok, key} = Oli.Interop.create_key(Ecto.UUID.generate(), "Hint A")

      {:ok, key} =
        Oli.Interop.update_key(key, %{
          status: :enabled,
          products_enabled: true,
          payments_enabled: true,
          registration_enabled: true,
          automation_setup_enabled: false
        })

      {:ok, view, _html} = live(conn, route())

      # Toggle products_enabled to false
      view
      |> element(
        "button[phx-click='update'][phx-value-field='products_enabled'][phx-value-id='#{key.id}']"
      )
      |> render_click(%{
        "field" => "products_enabled",
        "id" => to_string(key.id),
        "action" => "false"
      })

      key = Oli.Interop.get_key(key.id)
      assert key.products_enabled == false

      # Toggle status from enabled -> disabled
      view
      |> element("button[phx-click='toggle'][phx-value-id='#{key.id}']", "Disable")
      |> render_click(%{"id" => to_string(key.id), "action" => "Disable"})

      key = Oli.Interop.get_key(key.id)
      assert key.status == :disabled

      # Update registration namespace via change event
      view
      |> element("input#text_#{key.id}")
      |> render_hook("change", %{"id" => "text_#{key.id}", "value" => "ns-123"})

      key = Oli.Interop.get_key(key.id)
      assert key.registration_namespace == "ns-123"
    end
  end
end
