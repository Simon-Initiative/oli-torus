defmodule OliWeb.Curriculum.ContainerLiveTest do
  use OliWeb.ConnCase
  alias Oli.Seeder
  alias Oli.Publishing.AuthoringResolver

  import Plug.Conn
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint OliWeb.Endpoint

  describe "container live test" do
    setup [:setup_session]

    test "disconnected and connected mount", %{conn: conn, project: project, map: map} do
      conn = get(conn, "/project/#{project.slug}/curriculum/#{AuthoringResolver.root_container(project.slug).slug}")

      # Routing to the root container redirects to the `curriculum` path
      redir_path = "/project/#{project.slug}/curriculum"
      assert redirected_to(conn, 302) =~ redir_path
      conn = get(recycle(conn), redir_path)

      # The implicit root container path (/curriculum/) should show the root container resources
      {:ok, view, _} = live(conn)

      # the container should have two pages
      page1 = Map.get(map, :page1)
      page2 = Map.get(map, :page2)

      assert view |> element("##{Integer.to_string(page1.id)}") |> has_element?()
      assert view |> element("##{Integer.to_string(page2.id)}") |> has_element?()
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

    lti_params = Oli.TestHelpers.Lti_1p3.all_default_claims()
      |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.context_id)

    Oli.Lti_1p3.cache_lti_params!(lti_params["sub"], lti_params)

    conn = Plug.Test.init_test_session(conn, current_author_id: map.author.id)
      |> put_session(:current_user_id, user.id)
      |> put_session(:lti_1p3_sub, lti_params["sub"])

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
