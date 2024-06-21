defmodule OliWeb.Projects.OverviewLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Authoring.Course
  alias OliWeb.Endpoint
  alias OliWeb.Projects.OverviewLive

  describe "author cannot access when is not logged in" do
    test "redirects to new session when accessing the index view", %{conn: conn} do
      {:error,
       {:redirect,
        %{
          flash: %{},
          to: "/authoring/session/new?request_path=%2Fauthoring%2Fproject%2Ftestproject"
        }}} = live(conn, Routes.live_path(Endpoint, OverviewLive, "testproject"))
    end
  end

  describe "project overview as author" do
    setup [:author_conn]

    test "loads the project correctly", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, OverviewLive, project.slug))
      assert has_element?(view, "h4", "Details")
      assert has_element?(view, "h4", "Project Attributes")
      assert has_element?(view, "h4", "Project Labels")
      assert has_element?(view, "h4", "Collaborators")
      assert has_element?(view, "h4", "Advanced Activities")
      assert has_element?(view, "h4", "Allow Duplication")
      assert has_element?(view, "h4", "Publishing Visibility")
      assert has_element?(view, "h4", "Notes")
      assert has_element?(view, "h4", "Course Discussions")
      assert has_element?(view, "h4", "Transfer Payment Codes")
      assert has_element?(view, "h4", "Actions")

      refute has_element?(view, "button", "Bulk Resource Attribute Edit")
      refute has_element?(view, "label", "Calculate embeddings on publish")
    end

    test "project gets deleted correctly", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, OverviewLive, project.slug))

      {:ok, view, _html} =
        element(view, "form[phx-submit=\"delete\"]")
        |> render_submit()
        |> follow_redirect(conn, "/authoring/projects")

      assert Course.get_project_by_slug(project.slug).status == :deleted
      assert has_element?(view, "button#button-new-project")
      refute has_element?(view, "a", project.title)
    end

    test "project gets updated correctly", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, OverviewLive, project.slug))

      element(view, "form[phx-submit=\"update\"]")
      |> render_submit(%{
        "project" => %{"title" => "updated title", "description" => "updated description"}
      })

      assert has_element?(view, "div.alert-info", "Project updated successfully.")
      assert has_element?(view, "input[name=\"project[title]\"][value=\"updated title\"]")
      assert has_element?(view, "textarea[name=\"project[description]\"]", "updated description")
    end

    test "project can enable required surveys", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, OverviewLive, project.slug))

      refute has_element?(view, "input[name=\"survey\"][checked]")

      element(view, "form[phx-change=\"set-required-survey\"]")
      |> render_change(%{
        survey: "on"
      })

      updated_project = Course.get_project!(project.id)
      assert updated_project.required_survey_resource_id != nil
      assert has_element?(view, "input[name=\"survey\"][checked]")
      assert has_element?(view, "a", "Edit survey")
    end

    test "project can disable required surveys", %{conn: conn, author: author} do
      project = create_project_with_author(author)
      Course.create_project_survey(project, author.id)

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, OverviewLive, project.slug))

      assert has_element?(view, "input[name=\"survey\"][checked]")

      element(view, "form[phx-change=\"set-required-survey\"]")
      |> render_change(%{})

      updated_project = Course.get_project!(project.id)
      assert updated_project.required_survey_resource_id == nil
      refute has_element?(view, "input[name=\"survey\"][checked]")
      refute has_element?(view, "a", "Edit survey")
    end

    test "project can enable transfer payment codes", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, ~p"/authoring/project/#{project.slug}/overview")

      refute project.allow_transfer_payment_codes

      element(view, "form[phx-change=\"set_allow_transfer\"]")
      |> render_change(%{})

      assert Course.get_project!(project.id).allow_transfer_payment_codes
    end

    test "project can disable transfer payment codes", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, project} = Course.update_project(project, %{allow_transfer_payment_codes: true})

      {:ok, view, _html} = live(conn, ~p"/authoring/project/#{project.slug}/overview")

      assert project.allow_transfer_payment_codes

      element(view, "form[phx-change=\"set_allow_transfer\"]")
      |> render_change(%{})

      refute Course.get_project!(project.id).allow_transfer_payment_codes
    end

    test "does not display datashop analytics link when author is not admin", %{
      conn: conn,
      author: author
    } do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, OverviewLive, project.slug))

      refute has_element?(
               view,
               "a[href=#{~p"/project/#{project.slug}/datashop"}]",
               "Datashop Analytics"
             )
    end

    defp create_project_with_author(author) do
      %{project: project} = base_project_with_curriculum(nil)
      insert(:author_project, project_id: project.id, author_id: author.id)
      project
    end
  end

  describe "project overview as admin" do
    setup [:admin_conn]

    test "loads the project correctly", %{conn: conn, admin: admin} do
      project = create_project_with_author(admin)

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, OverviewLive, project.slug))
      assert has_element?(view, "h4", "Details")
      assert has_element?(view, "h4", "Project Attributes")
      assert has_element?(view, "h4", "Project Labels")
      assert has_element?(view, "h4", "Collaborators")
      assert has_element?(view, "h4", "Advanced Activities")
      assert has_element?(view, "h4", "Allow Duplication")
      assert has_element?(view, "h4", "Publishing Visibility")
      assert has_element?(view, "h4", "Notes")
      assert has_element?(view, "h4", "Course Discussions")
      assert has_element?(view, "h4", "Actions")

      assert has_element?(view, "button", "Bulk Resource Attribute Edit")
      assert has_element?(view, "label", "Calculate embeddings on publish")
    end

    test "displays datashop analytics link when the project is published", %{
      conn: conn,
      admin: admin
    } do
      project = create_project_with_author(admin)

      Oli.Publishing.publish_project(
        project,
        "Datashop test",
        admin.id
      )

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, OverviewLive, project.slug))

      assert has_element?(
               view,
               "a[href=\"/project/#{project.slug}/datashop\"]",
               "Datashop Analytics"
             )
    end

    test "can update calculate_embeddings_on_publish attribute (false by default)", %{
      conn: conn,
      admin: admin
    } do
      project = create_project_with_author(admin)

      Oli.Publishing.publish_project(
        project,
        "Datashop test",
        admin.id
      )

      refute project.attributes.calculate_embeddings_on_publish

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, OverviewLive, project.slug))

      element(view, "form[phx-submit=\"update\"]")
      |> render_submit(%{
        "project" => %{
          "attributes" => %{
            "calculate_embeddings_on_publish" => "true"
          }
        }
      })

      assert Course.get_project!(project.id).attributes.calculate_embeddings_on_publish
    end

    test "disables datashop analytics link when the project is not published", %{
      conn: conn,
      admin: admin
    } do
      project = create_project_with_author(admin)

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, OverviewLive, project.slug))

      assert has_element?(
               view,
               "button[disabled=\"disabled\"]",
               "Datashop Analytics"
             )
    end
  end
end
