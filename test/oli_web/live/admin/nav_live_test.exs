defmodule OliWeb.Admin.NavLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Floki

  describe "admin workspace navigation" do
    setup [:admin_conn]

    test "shows admin nav entry and marks it active on /admin", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin")

      assert has_element?(view, "#desktop_admin_workspace_nav_link")
      assert nav_link_active?(view, "#desktop_admin_workspace_nav_link")
    end

    test "keeps admin nav active on admin sub-routes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      assert nav_link_active?(view, "#desktop_admin_workspace_nav_link")
    end

    test "keeps admin nav active on community routes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/authoring/communities")

      assert nav_link_active?(view, "#desktop_admin_workspace_nav_link")
    end
  end

  describe "non-admin authors" do
    setup [:author_conn]

    test "do not see the admin workspace nav entry", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      refute has_element?(view, "#desktop_admin_workspace_nav_link")
    end
  end

  defp nav_link_active?(view, selector) do
    view
    |> render()
    |> Floki.parse_fragment!()
    |> Floki.find("#{selector} div.relative")
    |> Enum.any?(fn {_tag, attrs, _children} ->
      attrs
      |> Enum.into(%{})
      |> Map.get("class", "")
      |> String.contains?("bg-[#FFE5C2]")
    end)
  end
end
