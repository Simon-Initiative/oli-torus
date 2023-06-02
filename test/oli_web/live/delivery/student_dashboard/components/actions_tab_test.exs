defmodule OliWeb.Delivery.StudentDashboard.Components.ActionsTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  defp live_view_students_actions_route(
         section_slug,
         student_id,
         tab
       ) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.StudentDashboard.StudentDashboardLive,
      section_slug,
      student_id,
      tab
    )
  end

  defp enrolled_student_and_instructor(%{section: section, instructor: instructor}) do
    student = insert(:user)
    Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
    Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
    %{student: student}
  end

  defp create_section_with_requires_payment(_) do
    section =
      insert(:section, %{
        requires_payment: true,
        amount: %{amount: "1000", currency: "USD"}
      })

    [section: section]
  end

  describe "user" do
    test "cannot access page when it is not logged in", %{conn: conn} do
      section = insert(:section)
      student = insert(:user)

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Fstudent_dashboard%2F#{student.id}%2Factions"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(
                 conn,
                 live_view_students_actions_route(section.slug, student.id, :actions)
               )
    end
  end

  describe "student" do
    setup [:user_conn]

    test "cannot access page", %{user: user, conn: conn} do
      section = insert(:section)
      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(
                 conn,
                 live_view_students_actions_route(section.slug, user.id, :actions)
               )
    end
  end

  describe "instructor" do
    setup [:instructor_conn, :section_without_pages]

    test "cannot access page if not enrolled to section", %{
      conn: conn,
      section: section
    } do
      student = insert(:user)
      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(
                 conn,
                 live_view_students_actions_route(section.slug, student.id, :actions)
               )
    end

    test "can access page if enrolled to section", %{
      conn: conn,
      section: section,
      instructor: instructor
    } do
      student = insert(:user)
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_actions_route(section.slug, student.id, :actions)
        )

      # Actions tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_actions_route(section.slug, student.id, :actions)}"].border-b-2},
               "Actions"
             )
    end
  end

  describe "Change enrrolled user role" do
    setup [:instructor_conn, :section_without_pages, :enrolled_student_and_instructor]

    test "gets rendered correctly", %{
      section: section,
      conn: conn,
      student: student
    } do
      {:ok, view, _html} =
        live(conn, live_view_students_actions_route(section.slug, student.id, :actions))

      # Actions tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_actions_route(section.slug, student.id, :actions)}"].border-b-2},
               "Actions"
             )

      assert has_element?(view, "span", "Change enrolled user role")
      assert has_element?(view, "select[name=filter_by_role_id]")
    end

    test "instructor can change student role", %{
      section: section,
      conn: conn,
      student: student
    } do
      user_role_id =
        Sections.get_user_role_from_enrollment(Sections.get_enrollment(section.slug, student.id))

      {:ok, view, _html} =
        live(conn, live_view_students_actions_route(section.slug, student.id, :actions))

      assert view |> element("option[value=#{Integer.to_string(user_role_id)}]")

      view
      |> element("form[phx-change=\"display_confirm_modal\"")
      |> render_change(%{filter_by_role_id: "3"})

      assert view
             |> element("div.modal-body")
             |> render() =~
               "Are you sure you want to change user role to #{student.given_name} #{student.family_name}"

      view
      |> element("button", "Ok")
      |> render_click()

      user_role_id_changed =
        Sections.get_user_role_from_enrollment(Sections.get_enrollment(section.slug, student.id))

      assert view |> element("option[value=#{Integer.to_string(user_role_id_changed)}]")
    end

    test "instructor can cancel the student's role change", %{
      section: section,
      conn: conn,
      student: student
    } do
      user_role_id =
        Sections.get_user_role_from_enrollment(Sections.get_enrollment(section.slug, student.id))

      {:ok, view, _html} =
        live(conn, live_view_students_actions_route(section.slug, student.id, :actions))

      assert view |> element("option[value=#{Integer.to_string(user_role_id)}]")

      view
      |> element("form[phx-change=\"display_confirm_modal\"")
      |> render_change(%{filter_by_role_id: "3"})

      assert view
             |> element("div.modal-body")
             |> render() =~
               "Are you sure you want to change user role to #{student.given_name} #{student.family_name}"

      view
      |> element("button", "Cancel")
      |> render_click()

      assert view |> element("option[value=#{Integer.to_string(user_role_id)}]")
    end
  end

  describe "Bypass payment as an admin user" do
    setup [:admin_conn, :create_section_with_requires_payment]

    test "gets rendered correctly", %{
      conn: conn,
      section: section
    } do
      student = insert(:user)

      Sections.enroll(student.id, section.id, [
        ContextRoles.get_role(:context_learner)
      ])

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_actions_route(section.slug, student.id, :actions)
        )

      # Actions tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_actions_route(section.slug, student.id, :actions)}"].border-b-2},
               "Actions"
             )

      assert has_element?(view, "span", "Bypass payment")
      assert has_element?(view, "button", "Apply Bypass Payment")
    end

    test "allow bypass payment for a user", %{conn: conn, section: section} do
      student = insert(:user)

      Sections.enroll(student.id, section.id, [
        ContextRoles.get_role(:context_learner)
      ])

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_actions_route(section.slug, student.id, :actions)
        )

      assert has_element?(view, "button", "Apply Bypass Payment")

      # Button to bypass payment is enabled by default
      view
      |> element("button[phx-click=\"display_bypass_modal\"]")
      |> render_click()

      assert view
             |> element("div.modal-body")
             |> render() =~
               "Are you sure you want to bypass payment for #{student.given_name} #{student.family_name}"

      view
      |> element("button", "Ok")
      |> render_click()

      # Button to byppas payment is disabled after bypassing payment
      assert view
             |> element("button[phx-click=\"display_bypass_modal\"][disabled]")
             |> render() =~
               "Apply Bypass Payment"
    end
  end

  describe "Bypass payment as an instructor user" do
    setup [:instructor_conn, :section_without_pages, :enrolled_student_and_instructor]

    test "button to bypass payment is not rendered if the user is not an admin user", %{
      conn: conn,
      student: student,
      section: section
    } do
      {:ok, updated_section} =
        Sections.update_section(section, %{
          requires_payment: true,
          amount: %{amount: "1000", currency: "USD"}
        })

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_actions_route(updated_section.slug, student.id, :actions)
        )

      # Actions tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_actions_route(updated_section.slug, student.id, :actions)}"].border-b-2},
               "Actions"
             )

      refute has_element?(view, "span", "Bypass payment")
      refute has_element?(view, "button", "Apply Bypass Payment")
    end
  end
end
