defmodule OliWeb.ContainerLiveTest do
  use OliWeb.ConnCase
  alias Oli.Seeder

  import Plug.Conn
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint OliWeb.Endpoint

  describe "container live test" do
    setup [:setup_session]

    test "disconnected and connected mount", %{conn: conn, project: project, map: map} do
      conn = get(conn, "/project/#{project.slug}/curriculum")

      {:ok, view, _} = live(conn)

      # the container should have two pages
      page1 = Map.get(map, :page1)
      page2 = Map.get(map, :page2)

      assert view |> element("##{Integer.to_string(page1.id)}") |> has_element?()
      assert view |> element("##{Integer.to_string(page2.id)}") |> has_element?()

      # click the first item to select it, this would makde the Settings view visible
      view
       |> element("##{Integer.to_string(page1.id)}")
       |> render_click() =~ "Grading Type"

      # delete the selected page
      view
       |> element(".btn-danger")
       |> render_click() =~ "The temperature is: 30℉"

      refute view |> element("##{Integer.to_string(page1.id)}") |> has_element?()
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

    conn = Plug.Test.init_test_session(conn, current_author_id: map.author.id)
      |> put_session(:current_user_id, user.id)
      # TODO replace with lti_params cache key
      |> put_session(:lti_params, %{"context_id" => section.context_id})

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
