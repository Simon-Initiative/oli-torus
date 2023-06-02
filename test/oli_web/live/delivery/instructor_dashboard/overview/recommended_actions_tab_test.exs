defmodule OliWeb.Delivery.InstructorDashboard.Overview.RecommendedActionsTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Ecto.Query, warn: false
  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Repo

  defp instructor_course_content_path(section_slug) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :overview,
      :recommended_actions
    )
  end

  defp enroll_instructor(%{section: section, instructor: instructor}) do
    enroll_user_to_section(instructor, section, :context_instructor)

    {:ok, []}
  end

  describe "Instructor dashboard overview - recommended_actions tab" do
    setup [:instructor_conn, :basic_section, :enroll_instructor]

    test "renders a \"no actions\" when no recommended actions exist", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      assert has_element?(view, "span", "No action needed")
    end

    test "renders the \"soft scheduling\" action when necessary", %{
      conn: conn,
      section: section
    } do
      {:ok, start_date} = DateTime.from_naive(~N[2023-05-24 00:00:00], "UTC")

      Oli.Delivery.Sections.SectionResource
      |> where([sr], sr.section_id == ^section.id)
      |> select([sr], sr)
      |> limit(1)
      |> Repo.one()
      |> Oli.Delivery.Sections.SectionResource.changeset(%{start_date: start_date})
      |> Repo.update()

      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      assert has_element?(view, "h4", "Scheduling")
      assert has_element?(view, "span", "You have not define a schedule for your course content")
    end

    test "renders the \"pending approval posts\" action when necessary", %{
      conn: conn,
      section: section,
      section_page: section_page
    } do
      user = insert(:user)

      insert(:post,
        section: section,
        resource: section_page.resource,
        user: user,
        status: :submitted
      )

      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      assert has_element?(view, "h4", "Approve Pending Posts")

      assert has_element?(
               view,
               "span",
               "You have 1 discussion post that is pending your approval"
             )
    end

    test "renders the \"score questions\" action when necessary", %{
      conn: conn,
      section: section,
      section_page: section_page
    } do
      user = insert(:user)

      resource_access =
        insert(:resource_access, user: user, section: section, resource: section_page.resource)

      resource_attempt = insert(:resource_attempt, resource_access: resource_access)

      insert(:activity_attempt,
        resource_attempt: resource_attempt,
        resource: section_page.resource,
        revision: section_page,
        lifecycle_state: :submitted
      )

      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      assert has_element?(view, "h4", "Score questions")

      assert has_element?(
               view,
               "span",
               "You have 1 question that is awaiting your manual scoring"
             )
    end

    test "renders the \"pending updates\" action when necessary", %{
      conn: conn,
      section: section,
      project: project
    } do
      insert(:publication, project: project, published: DateTime.utc_now())

      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      assert has_element?(view, "h4", "Pending course update")

      assert has_element?(
               view,
               "span",
               "There are available course content updates that you have not accepted"
             )
    end

    test "renders the \"remind student of deadlines\" action when necessary", %{
      conn: conn,
      section: section,
      section_page: section_page
    } do
      end_date = DateTime.utc_now() |> DateTime.add(10, :hour) |> DateTime.truncate(:second)

      section_page
      |> Ecto.Changeset.change(%{graded: true})
      |> Repo.update()

      Oli.Delivery.Sections.SectionResource
      |> where([sr], sr.resource_id == ^section_page.resource.id)
      |> select([sr], sr)
      |> limit(1)
      |> Repo.one()
      |> Ecto.Changeset.change(%{scheduling_type: :due_by, end_date: end_date})
      |> Repo.update()

      Oli.Resources.Revision
      |> where([rev], rev.resource_id == ^section_page.resource.id)
      |> select([sr], sr)
      |> Repo.all()

      Oli.Delivery.Sections.SectionResource
      |> where([sr], sr.resource_id == ^section_page.resource.id)
      |> select([sr], sr)
      |> Repo.all()

      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      assert has_element?(view, "h4", "Remind Students of Deadlines")

      assert has_element?(
               view,
               "span",
               "There are assessments due soon, review and remind students"
             )
    end
  end
end
