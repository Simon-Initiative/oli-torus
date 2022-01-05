defmodule OliWeb.ProjectVisibilityTest do
  use OliWeb.ConnCase
  alias Oli.Seeder
  alias Oli.Authoring.Course
  alias Oli.Publishing

  import Phoenix.LiveViewTest
  @endpoint OliWeb.Endpoint

  describe "visibility live test" do
    setup [:setup_session]

    test "project visibility update", %{
      conn: conn,
      project: project,
      author: author,
      institution: institution
    } do
      {:ok, view, _} =
        live_isolated(conn, OliWeb.Projects.VisibilityLive,
          session: %{"project_slug" => project.slug}
        )

      assert view |> element("#visibility_option_selected") |> has_element?()

      view
      |> element("#visibility_option")
      |> render_change(%{"visibility" => %{"option" => "global"}})

      updated_project = Course.get_project!(project.id)
      assert updated_project.visibility == :global

      available_publications = Publishing.available_publications(author, institution)
      assert Enum.count(available_publications) == 0

      Publishing.publish_project(project, "some changes")

      available_publications = Publishing.available_publications(author, institution)

      assert Enum.count(available_publications) == 1
    end

    test "suggests exact email matches when restricted visibility", %{
      conn: conn,
      project: project,
      author: author
    } do
      {:ok, view, _} =
        live_isolated(conn, OliWeb.Projects.VisibilityLive,
          session: %{"project_slug" => project.slug}
        )

      view
      |> element("#visibility_option")
      |> render_change(%{"visibility" => %{"option" => "selected"}})

      updated_project = Course.get_project!(project.id)
      assert updated_project.visibility == :selected

      # It doesn't search by prefix
      email_prefix = String.slice(author.email, 0..3)

      view
      |> element("#users form")
      |> render_change(%{"search_field" => %{"entity" => "instructors", "query" => email_prefix}})

      refute has_element?(view, "#user_submit")

      # It searches by exact email
      view
      |> element("#users form")
      |> render_change(%{"search_field" => %{"entity" => "instructors", "query" => author.email}})

      assert view
             |> element("#user_submit select")
             |> render() =~ author.email
    end
  end

  defp setup_session(%{conn: conn}) do
    map = Seeder.base_project_with_resource2()

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(map.author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok, conn: conn, author: map.author, institution: map.institution, project: map.project}
  end
end
