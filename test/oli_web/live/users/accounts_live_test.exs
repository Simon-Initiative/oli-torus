defmodule OliWeb.AccountsLiveTest do
  use OliWeb.ConnCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Oli.Seeder
  alias Oli.Accounts

  describe "accounts live test" do
    setup [:setup_session]

    test "accounts mount", %{conn: conn, admin: _admin, map: map} do
      conn = get(conn, Routes.live_path(conn, OliWeb.Accounts.AccountsLive))

      {:ok, view, _} = live(conn)

      author1 = Map.get(map, :author)
      author2 = Map.get(map, :author2)

      user1 = Map.get(map, :user1)
      user2 = Map.get(map, :user2)

      # the table should have two authors
      assert view |> element("tr#author-#{author1.id}") |> has_element?()
      assert view |> element("tr#author-#{author2.id}") |> has_element?()

      # select users view
      view
      |> element("a[href=\"#users\"]")
      |> render_click()

      # the table should have two users
      assert view |> element("tr#user-#{user1.id}") |> has_element?()
      assert view |> element("tr#user-#{user2.id}") |> has_element?()
    end
  end

  defp setup_session(%{conn: conn}) do
    admin = author_fixture(%{system_role_id: Accounts.SystemRole.role_id().admin})

    map =
      Seeder.base_project_with_resource2()
      |> Seeder.add_user(%{name: "user1"}, :user1)
      |> Seeder.add_user(%{name: "user2"}, :user2)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok,
     conn: conn,
     map: map,
     admin: admin,
     author: map.author,
     author2: map.author2,
     user1: map.user1,
     user2: map.user2,
     institution: map.institution,
     project: map.project,
     publication: map.publication}
  end
end
