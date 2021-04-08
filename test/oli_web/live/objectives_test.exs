defmodule OliWeb.ObjectivesLiveTest do
  use OliWeb.ConnCase
  alias Oli.Seeder

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint OliWeb.Endpoint

  describe "objectives live test" do
    setup [:setup_session]

    test "objectives mount", %{conn: conn, project: project, map: map} do
      conn = get(conn, "/project/#{project.slug}/objectives")

      {:ok, view, _} = live(conn)

      objective1 = Map.get(map, :objective1)
      objective2 = Map.get(map, :objective2)

      # the container should have two objectives
      assert view |> element("##{objective1.revision.slug}") |> has_element?()
      assert view |> element("##{objective2.revision.slug}") |> has_element?()

      # delete the selected objective, which requires first clicking the delete button
      # which will display the modal, then we click the "Delete" button in the modal
      view
      |> element("#delete_#{objective1.revision.slug}")
      |> render_click()

      view
      |> element(".btn-danger.confirm")
      |> render_click()

      refute view |> element("##{objective1.revision.slug}") |> has_element?()
      assert view |> element("##{objective2.revision.slug}") |> has_element?()
    end
  end

  defp setup_session(%{conn: conn}) do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.add_objective("objective 1", :objective1)
      |> Seeder.add_objective("objective 2", :objective2)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(map.author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok,
     conn: conn,
     map: map,
     author: map.author,
     institution: map.institution,
     project: map.project,
     publication: map.publication}
  end
end
