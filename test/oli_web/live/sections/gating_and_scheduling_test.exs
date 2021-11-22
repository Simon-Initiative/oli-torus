defmodule OliWeb.Sections.GatingAndSchedulingTest do
  use OliWeb.ConnCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Oli.Seeder
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  @endpoint OliWeb.Endpoint

  describe "gating and scheduling live test admin" do
    setup [:setup_admin_session]

    test "mount listing for admin", %{conn: conn, section: section} do
      {:ok, _view, html} =
        live(conn, Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug))

      assert html =~ "Gating and Scheduling"
    end
  end

  describe "gating and scheduling live test instructor" do
    setup [:setup_instructor_session]

    test "mount listing for instructor", %{conn: conn, section: section} do
      {:ok, _view, html} =
        live(conn, Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug))

      assert html =~ "Gating and Scheduling"
    end
  end

  defp setup_admin_session(%{conn: conn}) do
    %{section_1: section} = Seeder.base_project_with_resource4()
    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().admin})

    conn =
      Plug.Test.init_test_session(conn, [])
      |> Pow.Plug.assign_current_user(admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok, conn: conn, admin: admin, section: section}
  end

  defp setup_instructor_session(%{conn: conn}) do
    %{section_1: section} = Seeder.base_project_with_resource4()

    instructor = user_fixture()
    Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

    conn =
      Plug.Test.init_test_session(conn, [])
      |> Pow.Plug.assign_current_user(instructor, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    {:ok, conn: conn, instructor: instructor, section: section}
  end
end
