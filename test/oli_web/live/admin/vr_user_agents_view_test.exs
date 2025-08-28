defmodule OliWeb.Admin.VrUserAgentsViewTest do
  use OliWeb.ConnCase
  import Phoenix.LiveViewTest
  import Oli.Factory

  @live_view_route Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.VrUserAgentsView)

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the vr_user_agents view", %{conn: conn} do
      redirect_path = "/authors/log_in"

      assert {:error, {:redirect, %{to: ^redirect_path}}} = live(conn, "/admin/vr_user_agents")
    end
  end

  describe "users cannot access" do
    setup [:user_conn]

    test "redirects to authoring sign in", %{conn: conn} do
      redirect_path = "/authors/log_in"

      assert {:error, {:redirect, %{to: ^redirect_path}}} = live(conn, @live_view_route)
    end
  end

  describe "admins can access" do
    setup [:admin_conn]

    test "loads vr_user_agents view correctly", %{conn: conn} do
      {:ok, _view, html} = live(conn, @live_view_route)

      assert html =~ "VR User Agents"
    end
  end

  describe "Vr user agents view" do
    setup [:admin_conn, :user_agents_data]

    test "user interaction", %{
      conn: conn,
      user_agent_1: user_agent_1,
      user_agent_2: user_agent_2
    } do
      %{id: id_1, user_agent: user_agent_value_1} =
        insert(:vr_user_agent, user_agent: user_agent_1)

      %{id: id_2, user_agent: user_agent_value_2} =
        insert(:vr_user_agent, user_agent: user_agent_2)

      {:ok, view, _html} = live(conn, @live_view_route)

      assert [[^id_2, ^user_agent_value_2, "Delete"], [^id_1, ^user_agent_value_1, "Delete"]] =
               extract_rows_data(view)

      # Delete the second user agent
      view |> element("tbody tr:nth-of-type(1) td:nth-of-type(3) button") |> render_click()

      assert [[^id_1, ^user_agent_value_1, "Delete"]] = extract_rows_data(view)

      # Adds back the user agent 2
      view
      |> element("form[phx-submit='add_user_agent']")
      |> render_submit(%{"vr_user_agent" => %{"user_agent" => user_agent_value_2}})

      assert [[_new_id_2, ^user_agent_value_2, "Delete"], [^id_1, ^user_agent_value_1, "Delete"]] =
               extract_rows_data(view)
    end
  end

  defp extract_rows_data(view) do
    view
    |> render()
    |> Floki.parse_fragment!()
    |> Floki.find("tbody tr:nth-of-type(n)")
    |> Enum.map(fn tr -> Floki.children(tr) end)
    |> Enum.map(fn [id, user_agent, delete] ->
      [
        String.to_integer(String.trim(Floki.text(id))),
        String.trim(Floki.text(user_agent)),
        String.trim(Floki.text(delete))
      ]
    end)
  end

  defp user_agents_data(_context) do
    user_agent_1 =
      "Mozilla/5.0 (X11; Linux x86_64; Quest 2) AppleWebKit/537.36 (KHTML, like Gecko) OculusBrowser/16.0.0.4.13.298796165 SamsungBrowser/4.0 Chrome/91.0.4472.88 Safari/537.36"

    user_agent_2 =
      "Mozilla/5.0 (Linux; Android 10; Quest 2) AppleWebKit/537.36 (KHTML, like Gecko) OculusBrowser/16.6.0.1.52.314146309 SamsungBrowser/4.0 Chrome/91.0.4472.164 VR Safari/537.36"

    {:ok, user_agent_1: user_agent_1, user_agent_2: user_agent_2}
  end
end
