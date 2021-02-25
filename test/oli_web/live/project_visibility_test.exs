defmodule OliWeb.ProjectVisibilityTest do
  use OliWeb.ConnCase
  alias Oli.Seeder
  alias Oli.Authoring.Course
  alias Oli.Publishing

  import Phoenix.LiveViewTest
  @endpoint OliWeb.Endpoint

  describe "visibility live test" do
    setup [:setup_session]

    test "project visibility update", %{conn: conn, project: project, author: author, institution: institution} do

      {:ok, view, _} = live_isolated(conn, OliWeb.Projects.VisibilityLive, session: %{ "project_slug" => project.slug })

      assert view |> element("#visibility_option_selected") |> has_element?()

      view
      |> element("#visibility_option")
      |> render_change(%{"visibility" => %{"option" => "global"}})

      updated_project = Course.get_project!(project.id)
      assert updated_project.visibility == :global

      available_publications = Publishing.available_publications(author, institution)
      assert available_publications == []

      Publishing.publish_project(project)

      available_publications = Publishing.available_publications(author, institution)
      assert Enum.count(available_publications) == 2
    end

  end

  defp setup_session(%{conn: conn}) do
    user = user_fixture()

    map = Seeder.base_project_with_resource2()

    section = section_fixture(%{
      context_id: "some-context-id",
      project_id: map.project.id,
      publication_id: map.publication.id,
      institution_id: map.institution.id
    })

    lti_params = Oli.Lti_1p3.TestHelpers.all_default_claims()
                 |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.context_id)

    cache_lti_params("params-key", lti_params)

    conn = Plug.Test.init_test_session(conn, lti_1p3_params: "params-key")
           |> Pow.Plug.assign_current_user(map.author, get_pow_config(:author))
           |> Pow.Plug.assign_current_user(user, get_pow_config(:user))

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
