defmodule OliWeb.ProjectVisibilityTest do
  use OliWeb.ConnCase
  alias Oli.Seeder
  alias Oli.Authoring.Course
  alias Oli.Publishing

  import Phoenix.LiveViewTest
  import Oli.Factory
  @endpoint OliWeb.Endpoint

  describe "visibility live test for admin" do
    setup [:setup_session_admin]

    test "admin can see and use the visibility form", %{
      conn: conn,
      project: project,
      admin: admin
    } do
      {:ok, view, _} =
        live_isolated(conn, OliWeb.Projects.VisibilityLive,
          session: %{"project_slug" => project.slug, "current_author_id" => admin.id}
        )

      # Admin should see the visibility form
      assert has_element?(view, "#visibility_option")
      assert has_element?(view, "#visibility_option_authors")
      assert has_element?(view, "#visibility_option_global")
      assert has_element?(view, "#visibility_option_selected")

      # Admin should not see the non-admin message
      refute render(view) =~
               "To make this content public in the Torus Course Builder for any instructor to use, please use the Support tool and send us a request."
    end

    test "admin can update project visibility", %{
      conn: conn,
      project: project,
      admin: admin,
      institution: institution
    } do
      {:ok, view, _} =
        live_isolated(conn, OliWeb.Projects.VisibilityLive,
          session: %{"project_slug" => project.slug, "current_author_id" => admin.id}
        )

      view
      |> element("#visibility_option")
      |> render_change(%{"visibility" => %{"option" => "global"}})

      updated_project = Course.get_project!(project.id)
      assert updated_project.visibility == :global

      available_publications = Publishing.available_publications(admin, institution)
      assert Enum.count(available_publications) == 0

      Publishing.publish_project(project, "some changes", admin.id)

      available_publications = Publishing.available_publications(admin, institution)

      assert Enum.count(available_publications) == 1
    end

    test "admin can use exact email matches when restricted visibility", %{
      conn: conn,
      project: project,
      admin: admin
    } do
      {:ok, view, _} =
        live_isolated(conn, OliWeb.Projects.VisibilityLive,
          session: %{"project_slug" => project.slug, "current_author_id" => admin.id}
        )

      view
      |> element("#visibility_option")
      |> render_change(%{"visibility" => %{"option" => "selected"}})

      updated_project = Course.get_project!(project.id)
      assert updated_project.visibility == :selected

      # It doesn't search by prefix
      email_prefix = String.slice(admin.email, 0..3)

      view
      |> element("#users form")
      |> render_change(%{"instructor_search_field" => %{"query" => email_prefix}})

      refute has_element?(view, "#user_submit")

      # It searches by exact email
      view
      |> element("#users form")
      |> render_change(%{"instructor_search_field" => %{"query" => admin.email}})

      assert view
             |> element("#user_submit select")
             |> render() =~ admin.email
    end
  end

  describe "visibility live test for non-admin" do
    setup [:setup_session]

    test "non-admin sees message instead of visibility form", %{
      conn: conn,
      project: project,
      author: author
    } do
      {:ok, view, _} =
        live_isolated(conn, OliWeb.Projects.VisibilityLive,
          session: %{"project_slug" => project.slug, "current_author_id" => author.id}
        )

      # Non-admin should not see the visibility form
      refute has_element?(view, "#visibility_option")
      refute has_element?(view, "#visibility_option_authors")
      refute has_element?(view, "#visibility_option_global")
      refute has_element?(view, "#visibility_option_selected")

      # Non-admin should see the message
      assert render(view) =~
               "To make this content public in the Torus Course Builder for any instructor to use, please use the Support tool and send us a request."
    end

    test "non-admin can still update the allow duplication flag", %{
      conn: conn,
      project: project,
      author: author
    } do
      {:ok, view, _} =
        live_isolated(conn, OliWeb.Projects.VisibilityLive,
          session: %{"project_slug" => project.slug, "current_author_id" => author.id}
        )

      view
      |> element("#duplication_option")
      |> render_change(%{"duplication" => %{"allow_duplication" => true}})

      updated_project = Course.get_project!(project.id)
      assert updated_project.allow_duplication
    end

    test "non-admin cannot change visibility via direct event call", %{
      conn: conn,
      project: project,
      author: author
    } do
      {:ok, view, _} =
        live_isolated(conn, OliWeb.Projects.VisibilityLive,
          session: %{"project_slug" => project.slug, "current_author_id" => author.id}
        )

      # Try to bypass UI by sending the event directly
      render_change(view, "option", %{"visibility" => %{"option" => "global"}})

      # Visibility should NOT have changed
      updated_project = Course.get_project!(project.id)
      refute updated_project.visibility == :global
    end

    test "non-admin cannot add restricted visibility via direct event call", %{
      conn: conn,
      project: project,
      author: author
    } do
      initial_visibilities_count =
        Enum.count(Publishing.get_all_project_visibilities(project.id))

      {:ok, view, _} =
        live_isolated(conn, OliWeb.Projects.VisibilityLive,
          session: %{"project_slug" => project.slug, "current_author_id" => author.id}
        )

      # Try to add an author to restricted visibility by sending event directly
      render_change(view, "selected_email", %{"multi" => %{"emails" => ["#{author.id}"]}})

      # No new visibility should have been added
      updated_visibilities =
        Publishing.get_all_project_visibilities(project.id)

      assert Enum.count(updated_visibilities) == initial_visibilities_count
    end

    test "non-admin cannot delete visibility restrictions via direct event call", %{
      conn: conn,
      project: project,
      author: author
    } do
      # Set up a visibility restriction
      {:ok, _project} = Course.update_project(project, %{visibility: :selected})

      {:ok, visibility} =
        Publishing.insert_visibility(%{project_id: project.id, author_id: author.id})

      {:ok, view, _} =
        live_isolated(conn, OliWeb.Projects.VisibilityLive,
          session: %{"project_slug" => project.slug, "current_author_id" => author.id}
        )

      # Try to delete the visibility restriction by sending event directly
      render_change(view, "delete_visibility", %{"id" => "#{visibility.id}"})

      # Visibility restriction should still exist
      updated_visibilities =
        Publishing.get_all_project_visibilities(project.id)

      assert Enum.any?(updated_visibilities, fn v ->
               v.visibility && v.visibility.id == visibility.id
             end)
    end
  end

  defp setup_session(%{conn: conn}) do
    map = Seeder.base_project_with_resource2()

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> log_in_author(map.author)

    {:ok, conn: conn, author: map.author, institution: map.institution, project: map.project}
  end

  defp setup_session_admin(%{conn: conn}) do
    map = Seeder.base_project_with_resource2()
    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().system_admin})

    # Add admin as a collaborator to the project
    insert(:author_project, project_id: map.project.id, author_id: admin.id)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> log_in_author(admin)

    {:ok, conn: conn, admin: admin, institution: map.institution, project: map.project}
  end
end
