defmodule OliWeb.Curriculum.ContainerLiveTest do
  use OliWeb.ConnCase
  alias Oli.Seeder
  alias Oli.Publishing.AuthoringResolver

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint OliWeb.Endpoint

  describe "container live test" do
    setup [:setup_session]

    test "disconnected and connected mount", %{conn: conn, author: author, project: project, map: map} do
      conn = get(conn, "/project/#{project.slug}/curriculum/#{AuthoringResolver.root_container(project.slug).slug}")

      # Routing to the root container redirects to the `curriculum` path
      redir_path = "/project/#{project.slug}/curriculum"
      assert redirected_to(conn, 302) =~ redir_path

      conn = recycle(conn)
        |> Pow.Plug.assign_current_user(author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

      conn = get(conn, redir_path)

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
    map = Seeder.base_project_with_resource2()

    conn = Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(map.author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok,
      conn: conn,
      map: map,
      author: map.author,
      project: map.project
    }
  end

end
