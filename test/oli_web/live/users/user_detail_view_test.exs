defmodule OliWeb.Users.UsersDetailViewTest do
  use OliWeb.ConnCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Oli.Seeder
  alias Oli.Accounts

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
        |> Pow.Plug.assign_current_user(admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

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
        |> get(
          Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, independent_student.id)
        )

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
        |> Pow.Plug.assign_current_user(admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

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
        |> Pow.Plug.assign_current_user(admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

      conn =
        get(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, independent_student.id)
        )

      {:ok, _view, html} = live(conn)

      assert html =~ "LTI 1.3 details" == false
      assert html =~ "LTI users are managed by the LMS" == false
    end
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

    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().admin})

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil, section_slug: map.section_1.slug)
      |> Pow.Plug.assign_current_user(instructor, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    {:ok,
     conn: conn, admin: admin, independent_student: independent_student, lms_student: lms_student}
  end
end
