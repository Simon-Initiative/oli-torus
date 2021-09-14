defmodule OliWeb.RemixSectionLiveTest do
  use OliWeb.ConnCase
  alias Oli.Seeder

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint OliWeb.Endpoint

  describe "remix section live test" do
    setup [:setup_session]

    test "remix section mount", %{conn: conn, project: project, map: map} do
      throw("TODO")
    end
  end

  defp setup_session(%{conn: conn}) do
    map = Seeder.base_project_with_resource4()
    user = user_fixture()

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    {:ok,
     conn: conn,
     map: map,
     author: map.author,
     institution: map.institution,
     project: map.project,
     publication: map.publication}
  end
end
