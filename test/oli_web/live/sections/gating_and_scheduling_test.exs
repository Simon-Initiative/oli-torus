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

    test "mount listing for admin", %{conn: conn, section_1: section} do
      {:ok, _view, html} =
        live(conn, Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug))

      assert html =~ "Gating and Scheduling"
    end
  end

  describe "gating and scheduling live test instructor" do
    setup [:setup_instructor_session]

    test "mount listing for instructor", %{conn: conn, section_1: section} do
      {:ok, _view, html} =
        live(conn, Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling, section.slug))

      assert html =~ "Gating and Scheduling"
    end

    test "mount new for instructor", %{conn: conn, section_1: section} do
      {:ok, _view, html} =
        live(
          conn,
          Routes.live_path(@endpoint, OliWeb.Sections.GatingAndScheduling.New, section.slug)
        )

      assert html =~ "Create Gating Condition"
    end

    test "mount edit for instructor", %{conn: conn, section_1: section, page1: page1} do
      gc = gating_condition_fixture(%{section_id: section.id, resource_id: page1.id})

      {:ok, _view, html} =
        live(
          conn,
          Routes.live_path(
            @endpoint,
            OliWeb.Sections.GatingAndScheduling.Edit,
            section.slug,
            gc.id
          )
        )

      assert html =~ "Edit Gating Condition"
    end
  end

  defp setup_admin_session(%{conn: conn}) do
    map = Seeder.base_project_with_resource4()
    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().admin})

    conn =
      Plug.Test.init_test_session(conn, [])
      |> Pow.Plug.assign_current_user(admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok, Map.merge(map, %{conn: conn, admin: admin})}
  end

  defp setup_instructor_session(%{conn: conn}) do
    map = Seeder.base_project_with_resource4()

    instructor = user_fixture()
    Sections.enroll(instructor.id, map.section_1.id, [ContextRoles.get_role(:context_instructor)])

    conn =
      Plug.Test.init_test_session(conn, [])
      |> Pow.Plug.assign_current_user(instructor, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    {:ok, Map.merge(map, %{conn: conn, instructor: instructor})}
  end
end
