defmodule OliWeb.Delivery.StudentDashboard.Components.ActionsTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest
  import Ecto.Query, only: [where: 3, limit: 2]

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Paywall.Payment

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

    {:ok, student_enrollment} =
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])

    Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
    %{student: student, student_enrollment: student_enrollment}
  end

  defp create_section_with_requires_payment(_) do
    section =
      insert(:section, %{
        requires_payment: true,
        amount: Money.new(1000, "USD")
      })

    [section: section]
  end

  describe "user" do
    test "cannot access page when it is not logged in", %{conn: conn} do
      section = insert(:section)
      student = insert(:user)

      redirect_path =
        "/users/log_in"

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

    test "can unenroll students", %{
      section: section,
      conn: conn,
      instructor: instructor
    } do
      student = insert(:user)
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} =
        live(conn, live_view_students_actions_route(section.slug, student.id, :actions))

      # Actions tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_actions_route(section.slug, student.id, :actions)}"].border-b-2},
               "Actions"
             )

      assert has_element?(view, "button", "Unenroll")
      assert has_element?(view, "select[name=filter_by_role_id]")
      refute has_element?(view, "button", "Re-enroll")

      view
      |> with_target("#student_actions")
      |> render_click("unenroll", %{})

      assert_redirected(
        view,
        ~p"/sections/#{section.slug}/manage"
      )

      assert Enrollment
             |> where([e], e.user_id == ^student.id and e.section_id == ^section.id)
             |> limit(1)
             |> Oli.Repo.one()
             |> Map.get(:status) == :suspended
    end

    test "can re-enroll students that were suspended", %{
      section: section,
      conn: conn,
      instructor: instructor
    } do
      student = insert(:user)
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.unenroll_learner(student.id, section.id)

      {:ok, view, _html} =
        live(conn, live_view_students_actions_route(section.slug, student.id, :actions))

      # Actions tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_actions_route(section.slug, student.id, :actions)}"].border-b-2},
               "Actions"
             )

      assert has_element?(view, "button", "Re-enroll")
      refute has_element?(view, "button", "Unenroll")

      view
      |> with_target("#student_actions")
      |> render_click("re_enroll", %{})

      assert_redirected(
        view,
        ~p"/sections/#{section.slug}/manage"
      )

      assert Enrollment
             |> where([e], e.user_id == ^student.id and e.section_id == ^section.id)
             |> limit(1)
             |> Oli.Repo.one()
             |> Map.get(:status) == :enrolled
    end

    test "displays an error message when enrollment was not found", %{
      section: section,
      conn: conn,
      instructor: instructor
    } do
      student = insert(:user)
      # Does not enroll student
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live(conn, live_view_students_actions_route(section.slug, student.id, :actions))

      # Actions tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_actions_route(section.slug, student.id, :actions)}"].border-b-2},
               "Actions"
             )

      assert has_element?(view, "button", "Re-enroll")
      refute has_element?(view, "button", "Unenroll")

      view
      |> with_target("#student_actions")
      |> render_click("re_enroll", %{})

      assert render(view) =~ "Could not re-enroll the student. Previous enrollment was not found."
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
      |> element("form[phx-change='display_confirm_modal']")
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
      |> element("form[phx-change='display_confirm_modal']")
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
      |> element("button[phx-click='display_bypass_modal']")
      |> render_click()

      # and the update payment status action is not visible (since there is no active payment)
      refute has_element?(view, "span", "Update payment status")

      assert view
             |> element("div.modal-body")
             |> render() =~
               "Are you sure you want to bypass payment for #{student.given_name} #{student.family_name}"

      view
      |> element("button", "Ok")
      |> render_click()

      # Button to byppas payment is disabled after bypassing payment
      assert view
             |> element("button[phx-click='display_bypass_modal'][disabled]")
             |> render() =~
               "Apply Bypass Payment"

      # and the update payment status action is now visible (since there is an active payment that could be invalidated)
      assert has_element?(view, "span", "Update payment status")
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
          amount: Money.new(1000, "USD")
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

  describe "Transfer section data as an admin user" do
    setup [:admin_conn, :sections_with_same_publications]

    test "shows rendered button to transfer enrollment correctly", %{
      conn: conn,
      section_1: section_1,
      user_1: user_1
    } do
      Sections.enroll(user_1.id, section_1.id, [
        ContextRoles.get_role(:context_learner)
      ])

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_actions_route(section_1.slug, user_1.id, :actions)
        )

      # Actions tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_actions_route(section_1.slug, user_1.id, :actions)}"].border-b-2},
               "Actions"
             )

      assert has_element?(view, "span", "Transfer Enrollment")
      assert has_element?(view, "button", "Transfer Enrollment")
    end

    test "allow transfer enrollment to another section", %{
      conn: conn,
      section_1: section_1,
      section_2: section_2,
      user_1: user_1,
      user_2: user_2
    } do
      Sections.enroll(user_1.id, section_1.id, [
        ContextRoles.get_role(:context_learner)
      ])

      Sections.enroll(user_1.id, section_2.id, [
        ContextRoles.get_role(:context_learner)
      ])

      Sections.enroll(user_2.id, section_2.id, [
        ContextRoles.get_role(:context_learner)
      ])

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_actions_route(section_1.slug, user_1.id, :actions)
        )

      assert has_element?(view, "button", "Transfer Enrollment")

      # click button to transfer enrollment
      view
      |> with_target("#transfer_enrollment_modal")
      |> render_click("open", %{})

      # text in modal is correct
      assert view
             |> element("p[class=\"mb-2\"]")
             |> render() =~
               "This will transfer this student&#39;s enrollment, and all their current progress, to the selected course section. If this student is already enrolled in the selected course section, that progress will be lost."

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ "#{section_2.title}"

      # click on section_2 row
      view
      |> element(
        "tr[phx-value-id='#{section_2.id}']",
        "#{section_2.title}"
      )
      |> render_click()

      # shows the table element with the target students
      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ "#{user_1.name}"

      assert view
             |> element("tr:last-child > td:first-child")
             |> render() =~ "#{user_2.name}"

      # click on user_2 row
      view
      |> element(
        "tr[phx-value-id='#{user_2.id}']",
        "#{user_2.name}"
      )
      |> render_click()

      assert element(view, "p[class=\"my-4\"]") |> render() =~
               ~s"\n    Are you sure you want to transfer the <strong>#{user_1.name}</strong>\n    enrollment&#39;s in <strong>#{section_1.title}</strong>\n    to <strong>#{user_2.name}</strong>\n    in <strong>#{section_2.title}</strong>?\n"

      # click on confirm button
      view
      |> with_target("#transfer_enrollment")
      |> render_click("finish_transfer_enrollment")

      # shows success message
      assert has_element?(view, "div.alert.alert-info", "Enrollment successfully transfered")
    end

    test "shows text if there are no sections to transfer data", %{conn: conn, user_1: user_1} do
      section = insert(:section)

      Sections.enroll(user_1.id, section.id, [
        ContextRoles.get_role(:context_learner)
      ])

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_actions_route(section.slug, user_1.id, :actions)
        )

      assert has_element?(view, "button", "Transfer Enrollment")

      # click button to transfer enrollment
      view
      |> with_target("#transfer_enrollment_modal")
      |> render_click("open", %{})

      # shows text when there are not sections to transfer data
      assert view
             |> element("p.mt-4")
             |> render() =~
               "There are no other sections to transfer this student to."
    end

    test "shows text if there are no students to transfer data", %{
      conn: conn,
      section_1: section_1,
      section_2: section_2,
      user_1: user_1
    } do
      # section = insert(:section)

      Sections.enroll(user_1.id, section_1.id, [
        ContextRoles.get_role(:context_learner)
      ])

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_actions_route(section_1.slug, user_1.id, :actions)
        )

      assert has_element?(view, "button", "Transfer Enrollment")

      # click button to transfer enrollment
      view
      |> with_target("#transfer_enrollment_modal")
      |> render_click("open", %{})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ "#{section_2.title}"

      # click on section_2 row
      view
      |> element(
        "tr[phx-value-id='#{section_2.id}']",
        "#{section_2.title}"
      )
      |> render_click()

      # shows text when there are not sections to transfer data
      assert view
             |> element("p.mt-4")
             |> render() =~
               "There are no other students to transfer this student to."
    end
  end

  describe "Transfer section data as an instructor user" do
    setup [:instructor_conn, :sections_with_same_publications]

    test "button to transfer enrollment is not rendered if the user is not an admin user", %{
      conn: conn,
      section_1: section_1,
      instructor: instructor,
      user_1: user_1
    } do
      Sections.enroll(user_1.id, section_1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(instructor.id, section_1.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_actions_route(section_1.slug, user_1.id, :actions)
        )

      # Actions tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_actions_route(section_1.slug, user_1.id, :actions)}"].border-b-2},
               "Actions"
             )

      refute has_element?(view, "span", "Transfer Enrollment")
      refute has_element?(view, "button", "Transfer")
    end
  end

  describe "Update payment status for admin" do
    setup [:admin_conn, :create_section_with_requires_payment]

    test "is not visible for an admin if there is no payment for that student", %{
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

      refute has_element?(view, "span", "Update payment status")
    end

    test "can be set to not paid by an admin", %{
      conn: conn,
      section: section,
      admin: admin
    } do
      # insert, enroll and set payment for a student
      student = insert(:user)

      {:ok, %Oli.Delivery.Sections.Enrollment{id: enrollment_id}} =
        Sections.enroll(student.id, section.id, [
          ContextRoles.get_role(:context_learner)
        ])

      {:ok, payment} =
        Paywall.create_payment(%{
          generation_date: DateTime.utc_now(),
          amount: Money.new(50, "USD"),
          section_id: section.id,
          enrollment_id: enrollment_id
        })

      assert payment.type == :direct
      refute payment.invalidated_by_user_id

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_actions_route(section.slug, student.id, :actions)
        )

      assert has_element?(view, "span", "Update payment status")

      assert has_element?(
               view,
               "#payment_status_modal",
               "Are you sure you want to change the payment status of #{student.name} in the course #{section.title} to NOT PAID?"
             )

      # we directly confirm the change in the modal since we cannot trigger the modal
      # from the test (JS is not executed)

      view
      |> element("button[id=payment_status_modal-confirm]", "Confirm")
      |> render_click()

      # the action is not visible anymore and the student's payment status in invalidated
      refute has_element?(view, "span", "Update payment status")

      updated_payment = Oli.Repo.get(Payment, payment.id)

      assert updated_payment.type == :invalidated
      assert updated_payment.invalidated_by_user_id == admin.id
    end
  end

  describe "Update payment status for instructor" do
    setup [:instructor_conn, :section_without_pages, :enrolled_student_and_instructor]

    test "is not visible (even for students that have already paid)", %{
      conn: conn,
      section: section,
      student: student,
      student_enrollment: student_enrollment
    } do
      {:ok, _payment} =
        Paywall.create_payment(%{
          generation_date: DateTime.utc_now(),
          amount: Money.new(50, "USD"),
          section_id: section.id,
          enrollment_id: student_enrollment.id
        })

      {:ok, view, _html} =
        live(
          conn,
          live_view_students_actions_route(section.slug, student.id, :actions)
        )

      refute has_element?(view, "span", "Update payment status")
    end
  end
end
