defmodule OliWeb.Delivery.InstructorDashboard.ManageTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  defp live_view_manage_route(section_slug) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :manage
    )
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Finstructor_dashboard%2Fmanage"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_manage_route(section.slug))
    end
  end

  describe "student" do
    setup [:user_conn]

    test "can not access page", %{user: user, conn: conn} do
      section = insert(:section)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_manage_route(section.slug))
    end
  end

  describe "instructor" do
    setup [:instructor_conn, :section_with_assessment]

    test "cannot access page if not enrolled to section", %{conn: conn, section: section} do
      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_manage_route(section.slug))
    end

    test "can access page if enrolled to section", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_manage_route(section.slug))

      # Manage tab content gets rendered
      assert has_element?(view, ~s{div[id="overview"]})

      # Collab Space Group gets rendered
      assert render(view) =~ "Collaborative Space"
    end

    test "can enable and disable agenda", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live_isolated(
          conn,
          OliWeb.Sections.OverviewView,
          session: %{
            "section_slug" => section.slug,
            "current_user_id" => instructor.id
          }
        )

      refute has_element?(view, "input[name=\"toggle_agenda\"][checked]")

      element(view, "form[phx-change=\"toggle_agenda\"]")
      |> render_change(%{})

      assert has_element?(view, "input[name=\"toggle_agenda\"][checked]")

      element(view, "form[phx-change=\"toggle_agenda\"]")
      |> render_change(%{})

      refute has_element?(view, "input[name=\"toggle_agenda\"][checked]")
    end
  end
end
