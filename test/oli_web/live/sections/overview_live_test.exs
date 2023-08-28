defmodule OliWeb.Sections.OverviewLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Repo

  defp live_view_overview_route(section_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section_slug)
  end

  defp create_section(_conn) do
    section = insert(:section)

    [section: section]
  end

  describe "user cannot access when is not logged in" do
    setup [:create_section]

    test "redirects to new session when accessing the section overview view", %{
      conn: conn,
      section: section
    } do
      section_slug = section.slug

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section_slug}&section=#{section_slug}"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_overview_route(section.slug))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :create_section]

    test "redirects to new session when accessing the section overview view", %{
      conn: conn,
      section: section
    } do
      conn = get(conn, live_view_overview_route(section.slug))

      redirect_path = "/session/new?request_path=%2Fsections%2F#{section.slug}"
      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "user cannot access when is logged in as an instructor but is not enrolled in the section" do
    setup [:user_conn]

    test "redirects to new session when accessing the section overview view", %{
      conn: conn
    } do
      section = insert(:section, %{type: :enrollable})

      conn = get(conn, live_view_overview_route(section.slug))

      redirect_path = "/unauthorized"
      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "user cannot access when is logged in as a student and is enrolled in the section" do
    setup [:user_conn]

    test "redirects to new session when accessing the section overview view", %{
      conn: conn,
      user: user
    } do
      section = insert(:section, %{type: :enrollable})
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, live_view_overview_route(section.slug))

      redirect_path = "/unauthorized"
      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "user can access when is logged in as an instructor and is enrolled in the section" do
    setup [:user_conn, :section_with_assessment]

    test "loads correctly", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, _view, html} = live(conn, live_view_overview_route(section.slug))

      assert html =~ "Details"
    end
  end

  describe "admin is prioritized over instructor when both logged in" do
    setup [:admin_conn, :user_conn, :section_with_assessment]

    test "loads correctly", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, _view, html} = live(conn, live_view_overview_route(section.slug))

      assert html =~ "<nav aria-label=\"breadcrumb"
      assert html =~ "Overview"
    end
  end

  describe "overview live view as admin" do
    setup [:admin_conn, :section_with_assessment]

    test "returns 404 when section not exists", %{conn: conn} do
      conn = get(conn, live_view_overview_route("not_exists"))

      assert response(conn, 404)
    end

    test "loads section data correctly", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert render(view) =~ "Details"
      assert render(view) =~ "Overview of course section details"
      assert has_element?(view, "input[value=\"#{section.slug}\"]")
      assert has_element?(view, "input[value=\"#{section.title}\"]")
      assert has_element?(view, "input[value=\"Direct Delivery\"]")
      assert has_element?(view, "a", section.base_project.title)

      assert view |> element("a.form-control") |> render() =~
               section.lti_1p3_deployment.institution.name
    end

    test "loads title of the product on which the section is based if it exists.", %{
      conn: conn,
      section: section
    } do
      product = insert(:section, %{type: :blueprint})

      {:ok, section} =
        Sections.update_section(section, %{blueprint_id: product.id, blueprint: product})

      section = section |> Repo.preload(:blueprint)

      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert render(view) =~ "Details"
      assert render(view) =~ "Overview of course section details"
      assert has_element?(view, "input[value=\"#{section.title}\"]")
      assert has_element?(view, "a", section.blueprint.title)
    end

    test "loads section instructors correctly", %{conn: conn, section: section} do
      user_enrolled = insert(:user)
      user_not_enrolled = insert(:user, %{given_name: "Other"})

      Sections.enroll(user_enrolled.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert render(view) =~ "Instructors"
      assert render(view) =~ "Manage users with instructor level access"
      assert render(view) =~ user_enrolled.given_name
      refute render(view) =~ user_not_enrolled.given_name
    end

    test "loads section links correctly", %{conn: conn, section: section} do
      {:ok, section} = Sections.update_section(section, %{open_and_free: false})
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))
      assert render(view) =~ "Curriculum"
      assert render(view) =~ "Manage content delivered to students"

      assert has_element?(
               view,
               "a[href=\"#{Routes.page_delivery_path(OliWeb.Endpoint, :index_preview, section.slug)}\"]",
               "Preview Course as Instructor"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.RemixSection, section.slug)}\"]",
               "Customize Curriculum"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.ScheduleView, section.slug)}\"]",
               "Scheduling"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.GatingAndScheduling, section.slug)}\"]",
               "Advanced Gating and Scheduling"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.source_materials_path(OliWeb.Endpoint, OliWeb.Delivery.ManageSourceMaterials, section.slug)}\"]",
               "Manage Source Materials"
             )

      assert render(view) =~ "Manage"
      assert render(view) =~ "Manage all aspects of course delivery"

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EnrollmentsViewLive, section.slug)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EditView, section.slug)}\"]"
             )

      assert render(view) =~ "Grading"
      assert render(view) =~ "View and manage student grades and progress"

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.GradebookView, section.slug)}\"]",
               "View all Grades"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.page_delivery_path(OliWeb.Endpoint, :export_gradebook, section.slug)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.GradesLive, section.slug)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.FailedGradeSyncLive, section.slug)}\"]",
               "View Grades that failed to sync"
             )
    end

    test "unlink section from lms", %{conn: conn, section: section} do
      {:ok, section} = Sections.update_section(section, %{open_and_free: false})
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert render(view) =~ "LMS Admin"
      assert render(view) =~ "Administrator LMS Connection"

      view
      |> element("button[phx-click=\"unlink\"]")
      |> render_click()

      assert_redirected(view, Routes.delivery_path(OliWeb.Endpoint, :index))
      assert %Section{status: :deleted} = Sections.get_section!(section.id)
    end

    test "deletes a section when it has no students associated data", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert render(view) =~
               "Delete Section"

      view
      |> element("button[phx-click=\"show_delete_modal\"]")
      |> render_click()

      assert view
             |> element("#delete_section_modal")
             |> render() =~
               "This action cannot be undone. Are you sure you want to delete this section?"

      view
      |> element("button[phx-click=\"delete_section\"]")
      |> render_click()

      system_role_id = conn.assigns.current_author.system_role_id

      redirect_path =
        if system_role_id == 2 do
          Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.SectionsView)
        else
          ~p"/sections"
        end

      assert_redirected(view, redirect_path)
      refute Sections.get_section_by_slug(section.slug)
    end

    test "archives a section when it has students associated data", %{
      conn: conn,
      section: section
    } do
      insert(:snapshot, section: section)

      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert render(view) =~
               "Delete Section"

      view
      |> element("button[phx-click=\"show_delete_modal\"]")
      |> render_click()

      assert view
             |> element("#delete_section_modal")
             |> render() =~
               "This section has student data and will be archived rather than deleted.\n  Are you sure you want to archive it? You will no longer have access to the data. Archiving this section will make it so students can no longer access it.\n"

      view
      |> element("button[phx-click=\"delete_section\"]")
      |> render_click()

      system_role_id = conn.assigns.current_author.system_role_id

      redirect_path =
        if system_role_id == 2 do
          Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.SectionsView)
        else
          ~p"/sections"
        end

      assert_redirected(view, redirect_path)
      assert %Section{status: :archived} = Sections.get_section!(section.id)
    end

    test "displays a flash message when there is student activity after the modal shows up", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert render(view) =~
               "Delete Section"

      view
      |> element("button[phx-click=\"show_delete_modal\"]")
      |> render_click()

      assert view
             |> element("#delete_section_modal")
             |> render() =~
               "This action cannot be undone. Are you sure you want to delete this section?"

      # Add student activity to the section
      insert(:snapshot, section: section)

      view
      |> element("button[phx-click=\"delete_section\"]")
      |> render_click()

      assert render(view) =~
               "Section had student activity recently. It can now only be archived, please try again."

      assert %Section{status: :active} = Sections.get_section!(section.id)
    end

    test "renders Collaboration Space config correctly (when not enabled by authoring)", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))
      assert render(view) =~ "Collaborative Space"
      assert render(view) =~ "Collaborative spaces are not enabled by the course project"
    end

    test "renders Collaboration Space config correctly (when enabled by authoring)", %{
      conn: conn
    } do
      {:ok, %{section: section}} = create_project_with_collab_space_and_posts()
      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert render(view) =~ "Collaborative Space"
      assert has_element?(view, "#collab_space_config")
    end
  end

  describe "overview live view as instructor" do
    setup [:instructor_conn, :section_with_assessment]

    test "returns 404 when section not exists", %{conn: conn} do
      conn = get(conn, live_view_overview_route("not_exists"))

      assert response(conn, 404)
    end

    test "loads section data correctly", %{conn: conn, instructor: instructor, section: section} do
      enroll_user_to_section(instructor, section, :context_instructor)

      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert render(view) =~ "Details"
      assert render(view) =~ "Overview of course section details"
      assert has_element?(view, "input[value=\"#{section.slug}\"]")
      assert has_element?(view, "input[value=\"#{section.title}\"]")
      assert has_element?(view, "input[value=\"Direct Delivery\"]")
      assert has_element?(view, "input[value=\"#{section.lti_1p3_deployment.institution.name}\"]")

      assert has_element?(
               view,
               "a[href=\"#{Routes.page_delivery_path(OliWeb.Endpoint, :index_preview, section.slug)}\"]",
               "Preview Course as Instructor"
             )
    end
  end

  describe "overview live required surveys" do
    setup [:instructor_conn, :section_with_disabled_survey]

    test "can enable required surveys", %{conn: conn, instructor: instructor, section: section} do
      enroll_user_to_section(instructor, section, :context_instructor)

      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      refute has_element?(view, "input[name=\"survey\"][checked]")

      element(view, "form[phx-change=\"set-required-survey\"]")
      |> render_change(%{
        survey: "on"
      })

      update_section = Oli.Delivery.Sections.get_section!(section.id)
      assert update_section.required_survey_resource_id != nil
      assert has_element?(view, "input[name=\"survey\"][checked]")
      refute has_element?(view, "a", "Edit survey")
    end

    test "can disable required surveys", %{conn: conn, instructor: instructor, section: section} do
      enroll_user_to_section(instructor, section, :context_instructor)
      Oli.Delivery.Sections.create_required_survey(section)

      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      assert has_element?(view, "input[name=\"survey\"][checked]")

      element(view, "form[phx-change=\"set-required-survey\"]")
      |> render_change(%{})

      update_section = Oli.Delivery.Sections.get_section!(section.id)
      assert update_section.required_survey_resource_id == nil
      refute has_element?(view, "input[name=\"survey\"][checked]")
    end

    test "can't enable surveys if the project doesn't allow it", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      enroll_user_to_section(instructor, section, :context_instructor)

      Oli.Authoring.Course.delete_project_survey(section.base_project)

      {:ok, view, _html} = live(conn, live_view_overview_route(section.slug))

      refute has_element?(view, "form[phx-change=\"set-required-survey\"]")

      assert has_element?(
               view,
               "p",
               "You are not allowed to have student surveys in this resource."
             )
    end
  end

  defp section_with_disabled_survey(conn), do: section_with_survey(conn, survey_enabled: false)
end
