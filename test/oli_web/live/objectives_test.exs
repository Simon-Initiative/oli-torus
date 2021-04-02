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
    user = user_fixture()

    map = Seeder.base_project_with_resource2()
            |> Seeder.add_objective("objective 1", :objective1)
            |> Seeder.add_objective("objective 2", :objective2)

    section = section_fixture(%{
      context_id: "some-context-id",
      project_id: map.project.id,
      publication_id: map.publication.id,
      institution_id: map.institution.id
    })

    lti_params = Oli.Lti_1p3.TestHelpers.all_default_claims()
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.context_id)

    cache_lti_params("params-key", lti_params)

    conn = Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(map.author, OliWeb.Pow.PowHelpers.get_pow_config(:author))
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    {:ok,
      conn: conn,
      map: map,
      author: map.author,
      institution: map.institution,
      user: user,
      project: map.project,
      publication: map.publication,
      section: section
    }
  end

end
