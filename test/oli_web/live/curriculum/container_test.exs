defmodule OliWeb.Curriculum.ContainerLiveTest do
  use OliWeb.ConnCase

  alias Oli.Seeder
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver

  import Oli.Factory
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint OliWeb.Endpoint

  describe "cannot access when is not logged in" do
    test "redirect to new session when accessing the container view", %{conn: conn} do
      project = insert(:project)

      redirect_path = "/authoring/session/new?request_path=%2Fauthoring%2Fproject%2F#{project.slug}%2Fcurriculum"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, Routes.container_path(@endpoint, :index, project.slug))
    end
  end

  describe "cannot access when is not an author" do
    setup [:user_conn]

    test "redirect to new session when accessing the container view", %{conn: conn} do
      project = insert(:project)

      redirect_path = "/authoring/session/new?request_path=%2Fauthoring%2Fproject%2F#{project.slug}%2Fcurriculum"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, Routes.container_path(@endpoint, :index, project.slug))
    end
  end

  describe "container live test" do
    setup [:setup_session]

    test "disconnected and connected mount", %{
      conn: conn,
      author: author,
      project: project,
      map: map
    } do
      conn =
        get(
          conn,
          "/authoring/project/#{project.slug}/curriculum/#{AuthoringResolver.root_container(project.slug).slug}"
        )

      # Routing to the root container redirects to the `curriculum` path
      redir_path = "/authoring/project/#{project.slug}/curriculum"
      assert redirected_to(conn, 302) =~ redir_path

      conn =
        recycle(conn)
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

    test "shows the author name editing the page correctly", %{
      conn: conn,
      project: project,
      map: %{
        published_resource1: published_resource1
      }
    } do
      editing_author = insert(:author)

      Publishing.update_published_resource(published_resource1, %{
        locked_by_id: editing_author.id,
        lock_updated_at: now()
      })

      {:ok, view, _} = live(conn, Routes.container_path(@endpoint, :index, project.slug))

      assert has_element?(view, "span", "#{editing_author.name} is editing")
    end
  end

  defp setup_session(%{conn: conn}) do
    map = Seeder.base_project_with_resource2()

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(map.author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok, conn: conn, map: map, author: map.author, project: map.project}
  end
end
