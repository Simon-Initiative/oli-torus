defmodule OliWeb.FeaturesLiveTest do
  use ExUnit.Case, async: false
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.RuntimeLogOverrides
  alias Oli.RuntimeLogOverrides.Registry

  defp live_view_route, do: ~p"/admin/features"

  setup do
    original_level = Logger.level()
    Logger.delete_all_module_levels()
    Registry.reset()

    on_exit(fn ->
      Logger.delete_all_module_levels()
      Registry.reset()
      Logger.configure(level: original_level)
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

  describe "module-level override UI" do
    setup [:admin_conn]

    test "renders the module override section and empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, live_view_route())

      assert has_element?(view, "#module-log-override-form")
      assert has_element?(view, "#apply-module-log-override", "Apply Override")

      assert has_element?(
               view,
               "#no-module-log-overrides",
               "No active module overrides on this node."
             )
    end

    test "applies an override and renders the active state", %{conn: conn} do
      {:ok, view, _html} = live(conn, live_view_route())

      view
      |> element("#module-log-override-form")
      |> render_submit(%{
        "module_override" => %{"module_name" => "Enum", "level" => "debug"}
      })

      assert render(view) =~ "Module log override applied to Enum"
      assert has_element?(view, "#active-module-log-overrides")
      assert has_element?(view, "#module-log-override-Elixir-Enum", "Elixir.Enum")
      assert [{Enum, :debug}] = Logger.get_module_level(Enum)
    end

    test "shows an error for an invalid module", %{conn: conn} do
      {:ok, view, _html} = live(conn, live_view_route())

      view
      |> element("#module-log-override-form")
      |> render_submit(%{
        "module_override" => %{"module_name" => "Not.A.Real.Module", "level" => "debug"}
      })

      assert render(view) =~ "Module log override failed: invalid module"
      assert has_element?(view, "#no-module-log-overrides")
      assert [] = RuntimeLogOverrides.list_overrides().modules
    end

    test "clears an active override", %{conn: conn} do
      {:ok, _} = RuntimeLogOverrides.set_module_level("Enum", :debug)

      {:ok, view, _html} = live(conn, live_view_route())

      assert has_element?(view, "#module-log-override-Elixir-Enum", "Elixir.Enum")

      view
      |> element("button[phx-click='clear_module_log_level'][phx-value-module='Elixir.Enum']")
      |> render_click()

      assert render(view) =~ "Module log override cleared for Elixir.Enum"
      assert has_element?(view, "#no-module-log-overrides")
      assert [] = Logger.get_module_level(Enum)
    end

    test "existing global logging control still works", %{conn: conn} do
      {:ok, view, _html} = live(conn, live_view_route())

      view
      |> element("button[phx-click='logging'][phx-value-level='warning']")
      |> render_click()

      assert render(view) =~ "Logging level changed to warning"
      assert Logger.level() == :warning
    end
  end
end
