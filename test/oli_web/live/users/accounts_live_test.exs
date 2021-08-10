defmodule OliWeb.AccountsLiveTest do
  use OliWeb.ConnCase
  alias Oli.Seeder

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint OliWeb.Endpoint

  describe "accounts live test" do
    setup [:setup_session]

    test "accounts mount", %{conn: conn, project: project, map: map} do
      # TODO
    end
  end

  defp setup_session(%{conn: conn}) do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.add_user(%{name: "user1"}, :user1)
      |> Seeder.add_user(%{name: "user2"}, :user2)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(map.author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok,
     conn: conn,
     map: map,
     author: map.author,
     author2: map.author2,
     user1: map.user1,
     user2: map.user2,
     institution: map.institution,
     project: map.project,
     publication: map.publication}
  end
end
