defmodule OliWeb.Users.UsersDetailViewTest do
  use OliWeb.ConnCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Seeder
  alias Oli.Accounts
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  @role_institution_instructor Lti_1p3.Tool.PlatformRoles.get_role(:institution_instructor)

  describe "user details live test" do
    setup [:setup_session]

    test "mount as administrator", %{
      conn: conn,
      admin: admin,
      lms_student: lms_student,
      independent_student: independent_student
    } do
      conn =
        Plug.Test.init_test_session(conn, %{})
        |> assign_current_author(admin)

      conn =
        get(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, lms_student.id)
        )

      {:ok, _view, html} = live(conn)

      assert html =~ "User details"
      assert html =~ lms_student.name

      conn =
        recycle_author_session(conn, admin)
        |> get(~p"/admin/users/#{independent_student.id}")

      {:ok, _view, html} = live(conn)

      assert html =~ "User details"
      assert html =~ independent_student.name
    end

    test "shows lms user lti params", %{
      conn: conn,
      lms_student: lms_student,
      admin: admin
    } do
      conn =
        Plug.Test.init_test_session(conn, %{})
        |> assign_current_author(admin)

      conn =
        get(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, lms_student.id)
        )

      {:ok, _view, html} = live(conn)

      [lti_params] = Oli.Lti.LtiParams.all_user_lti_params(lms_student.id)

      assert html =~ "LTI 1.3 details"
      assert html =~ lti_params.issuer
    end

    test "doesnt show independent user lti params", %{
      conn: conn,
      independent_student: independent_student,
      admin: admin
    } do
      conn =
        Plug.Test.init_test_session(conn, %{})
        |> assign_current_author(admin)

      conn =
        get(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, independent_student.id)
        )

      {:ok, _view, html} = live(conn)

      assert html =~ "LTI 1.3 details" == false
      assert html =~ "LTI users are managed by the LMS" == false
    end

    test "admin fails to update with an invalid user data", ctx do
      {:ok, view, _html} =
        Plug.Test.init_test_session(ctx.conn, [])
        |> assign_current_author(ctx.admin)
        |> live(~p"/admin/users/#{ctx.independent_student.id}")

      view
      |> element("button[phx-click=\"start_edit\"]", "Edit")
      |> render_click()

      # Params with invalid data to display errors
      params = %{
        "user" => %{
          "can_create_sections" => "false",
          "email" => "@test.com",
          "family_name" => "",
          "given_name" => "",
          "independent_learner" => "false"
        }
      }

      document =
        view
        |> element("form[phx-change=\"change\"")
        |> render_change(params)
        |> Floki.parse_document!()

      assert document
             |> Floki.find("[phx-feedback-for='user[family_name]'] > p")
             |> Floki.text() =~
               "can't be blank"

      assert document
             |> Floki.find("[phx-feedback-for='user[given_name]'] > p")
             |> Floki.text() =~
               "can't be blank"

      assert document
             |> Floki.find("[phx-feedback-for='user[email]'] > p")
             |> Floki.text() =~
               "has invalid format"

      assert has_element?(view, "[type='submit'][disabled]")

      {:ok, instructor_2} =
        Accounts.update_user_platform_roles(
          user_fixture(%{can_create_sections: true, independent_learner: true}),
          [@role_institution_instructor]
        )

      # Params to hit the users_email_independent_learner_index DB constraint
      params = %{
        "user" => %{
          "can_create_sections" => "false",
          "email" => "#{instructor_2.email}",
          "family_name" => "John",
          "given_name" => "Doe",
          "independent_learner" => "true"
        }
      }

      assert view
             |> element("form[phx-submit=\"submit\"")
             |> render_submit(params)
             |> Floki.parse_document!()
             |> Floki.find("[phx-feedback-for='user[email]'] > p")
             |> Floki.text() =~
               "Email has already been taken by another independent learner"

      assert has_element?(view, "[type='submit'][disabled]")
    end

    test "edit author details", %{
      conn: conn,
      admin: admin,
      independent_student: independent_student
    } do
      new_given_name = "New Given Name"
      new_last_name = "New Last Name"
      new_email = "new_email@example.com"

      conn =
        Plug.Test.init_test_session(conn, %{})
        |> assign_current_author(admin)

      conn =
        get(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, independent_student.id)
        )

      {:ok, view, _html} = live(conn)

      # Assert that fields are disabled
      assert has_element?(view, "input[value=\"#{independent_student.given_name}\"][disabled]")
      assert has_element?(view, "input[value=\"#{independent_student.family_name}\"][disabled]")
      assert has_element?(view, "input[value=\"#{independent_student.email}\"][disabled]")

      view
      |> element("button[phx-click=\"start_edit\"]", "Edit")
      |> render_click()

      # Assert that there is a save button
      assert has_element?(view, "button[type=\"submit\"]", "Save")

      # Refute that fields are disabled
      refute has_element?(view, "input[value=\"#{independent_student.given_name}\"][disabled]")
      refute has_element?(view, "input[value=\"#{independent_student.family_name}\"][disabled]")
      refute has_element?(view, "input[value=\"#{independent_student.email}\"][disabled]")

      view
      |> element("form[phx-submit=\"submit\"")
      |> render_submit(%{
        "user" => %{
          "given_name" => new_given_name,
          "family_name" => new_last_name,
          "email" => new_email
        }
      })

      # Assert that fields are updated correctly
      assert view |> element("input[value=\"#{new_given_name}\"][disabled]") |> render() =~
               new_given_name

      assert view |> element("input[value=\"#{new_last_name}\"][disabled]") |> render() =~
               new_last_name

      assert view |> element("input[value=\"#{new_email}\"][disabled]") |> render() =~ new_email

      # Assert that the name field was updated correctly
      assert view
             |> element("input[value=\"#{new_given_name} #{new_last_name}\"][disabled]")
             |> render() =~ "#{new_given_name} #{new_last_name}"
    end
  end

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the user details view", %{conn: conn} do
      student = insert(:user)

      assert conn
             |> get(Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, student.id))
             |> html_response(302) =~
               "You are being <a href=\"/authoring/session/new?request_path=%2Fadmin%2Fusers%2F#{student.id}\">redirected</a>"
    end
  end

  describe "student" do
    setup [:user_conn]

    test "redirects to new session when accessing the user details view as student", %{conn: conn} do
      student = insert(:user)

      assert conn
             |> get(Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, student.id))
             |> html_response(302) =~
               "You are being <a href=\"/authoring/session/new?request_path=%2Fadmin%2Fusers%2F#{student.id}\">redirected</a>"
    end
  end

  describe "instructor" do
    setup [:instructor_conn]

    test "redirects to new session when accessing the user details view as instructor", %{
      conn: conn
    } do
      student = insert(:user)

      assert conn
             |> get(Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, student.id))
             |> html_response(302) =~
               "You are being <a href=\"/authoring/session/new?request_path=%2Fadmin%2Fusers%2F#{student.id}\">redirected</a>"
    end
  end

  describe "System Admin" do
    setup [:admin_conn]

    test "can create a reset password link for a user", %{conn: conn} do
      user = insert(:user)

      {:ok, view, _html} =
        live(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, user.id))

      view
      |> element(~s{button[phx-click="generate_reset_password_link"]})
      |> render_click()

      assert has_element?(view, "p", "This link will expire in 24 hours.")

      assert view
             |> element(~s{input[id="password-reset-link-1"]})
             |> render()
             |> Floki.parse_fragment!()
             |> Floki.attribute("value")
             |> hd() =~ "/reset-password/"
    end
  end

  describe "Enrolled sections info" do
    setup [:admin_conn, :enrolled_student_to_sections, :stub_real_current_time]

    test "shows enrolled sections section", %{
      conn: conn,
      student: student
    } do
      {:ok, view, _html} =
        live(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, student.id))

      assert view |> element("h4", "Enrolled Sections")
      assert view |> element("div", "Course sections to which the student is enrolled")
    end

    test "shows message when student is not enrolled to any course section", %{
      conn: conn
    } do
      student = insert(:user)

      {:ok, view, _html} =
        live(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, student.id))

      assert view |> element("h6", "User is not enrolled in any course section")
    end

    test "shows enrolled sections info for a given student", %{
      conn: conn,
      student: student,
      section_1: section_1,
      section_2: section_2,
      section_3: section_3
    } do
      {:ok, view, _html} =
        live(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, student.id))

      assert has_element?(
               view,
               "a",
               "#{section_1.title}"
             )

      assert has_element?(
               view,
               "a",
               "#{section_2.title}"
             )

      assert has_element?(
               view,
               "a",
               "#{section_3.title}"
             )
    end

    test "applies searching", %{
      conn: conn,
      student: student,
      section_1: section_1,
      section_2: section_2,
      section_3: section_3
    } do
      {:ok, view, _html} =
        live(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, student.id))

      assert has_element?(
               view,
               "a",
               "#{section_1.title}"
             )

      assert has_element?(
               view,
               "a",
               "#{section_2.title}"
             )

      assert has_element?(
               view,
               "a",
               "#{section_3.title}"
             )

      # searching by section
      params = %{
        text_search: section_2.title
      }

      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, student.id, params)
        )

      refute has_element?(
               view,
               "a",
               "#{section_1.title}"
             )

      assert has_element?(
               view,
               "a",
               "#{section_2.title}"
             )

      refute has_element?(
               view,
               "a",
               "#{section_3.title}"
             )

      # searching by other section
      params = %{
        text_search: "other section"
      }

      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, student.id, params)
        )

      assert has_element?(
               view,
               "h6",
               "There are no sections to show"
             )
    end

    test "applies sorting", %{
      conn: conn,
      student: student,
      section_1: section_1,
      section_2: section_2,
      section_3: section_3
    } do
      {:ok, view, _html} =
        live(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, student.id))

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:first-child")
             |> render() =~ section_1.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(2)")
             |> render() =~ section_2.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:last-child")
             |> render() =~ section_3.title

      ## sorting by section
      params = %{
        sort_order: :desc
      }

      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, student.id, params)
        )

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:last-child")
             |> render() =~ section_1.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:nth-child(2)")
             |> render() =~ section_2.title

      assert view
             |> element("table.instructor_dashboard_table > tbody > tr:first-child")
             |> render() =~ section_3.title
    end

    test "applies pagination", %{
      conn: conn,
      student: student,
      section_1: section_1,
      section_2: section_2,
      section_3: section_3
    } do
      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, student.id)
        )

      assert has_element?(
               view,
               "a",
               "#{section_1.title}"
             )

      assert has_element?(
               view,
               "a",
               "#{section_2.title}"
             )

      assert has_element?(
               view,
               "a",
               "#{section_3.title}"
             )

      ## aplies limit
      params = %{
        limit: 2,
        sort_order: "asc"
      }

      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, student.id, params)
        )

      assert has_element?(
               view,
               "a",
               "#{section_1.title}"
             )

      assert has_element?(
               view,
               "a",
               "#{section_2.title}"
             )

      refute has_element?(
               view,
               "a",
               "#{section_3.title}"
             )

      ## aplies pagination
      params = %{
        limit: 2,
        offset: 2,
        sort_order: "asc"
      }

      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, student.id, params)
        )

      refute has_element?(
               view,
               "a",
               "#{section_1.title}"
             )

      refute has_element?(
               view,
               "a",
               "#{section_2.title}"
             )

      assert has_element?(
               view,
               "a",
               "#{section_3.title}"
             )
    end
  end

  defp enrolled_student_to_sections(%{conn: _conn}) do
    section_1 =
      insert(:section,
        type: :enrollable,
        start_date: yesterday(),
        end_date: tomorrow(),
        requires_payment: true
      )

    section_2 =
      insert(:section,
        type: :enrollable,
        start_date: yesterday(),
        end_date: tomorrow()
      )

    section_3 =
      insert(:section,
        type: :enrollable,
        start_date: yesterday(),
        end_date: tomorrow(),
        has_grace_period: true,
        grace_period_days: 10,
        requires_payment: true
      )

    student = insert(:user)
    Sections.enroll(student.id, section_1.id, [ContextRoles.get_role(:context_learner)])
    Sections.enroll(student.id, section_2.id, [ContextRoles.get_role(:context_learner)])
    Sections.enroll(student.id, section_3.id, [ContextRoles.get_role(:context_learner)])
    %{student: student, section_1: section_1, section_2: section_2, section_3: section_3}
  end

  defp setup_session(%{conn: conn}) do
    map = Seeder.base_project_with_resource4()

    {:ok, instructor} =
      Accounts.update_user_platform_roles(
        user_fixture(%{can_create_sections: true, independent_learner: true}),
        [
          Lti_1p3.Tool.PlatformRoles.get_role(:institution_instructor)
        ]
      )

    {:ok, independent_student} =
      Accounts.update_user_platform_roles(
        user_fixture(%{independent_learner: true}),
        [
          Lti_1p3.Tool.PlatformRoles.get_role(:institution_student)
        ]
      )

    {:ok, lms_student} =
      Accounts.update_user_platform_roles(
        user_fixture(%{independent_learner: false}),
        [
          Lti_1p3.Tool.PlatformRoles.get_role(:institution_student)
        ]
      )

    {:ok, _} =
      Oli.Lti.LtiParams.create_or_update_lti_params(
        Oli.Lti.TestHelpers.all_default_claims(),
        lms_student.id
      )

    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().system_admin})

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil, section_slug: map.section_1.slug)
      |> assign_current_user(instructor)

    {:ok,
     conn: conn,
     admin: admin,
     independent_student: independent_student,
     lms_student: lms_student,
     instructor: instructor}
  end
end
