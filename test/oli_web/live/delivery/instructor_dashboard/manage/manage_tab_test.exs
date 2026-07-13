defmodule OliWeb.Delivery.InstructorDashboard.ManageTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections

  defp live_view_manage_route(section_slug) do
    ~p"/sections/#{section_slug}/manage"
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)

      redirect_path =
        "/users/log_in"

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
      assert render(view) =~ " Overview of course section details"

      # Collab Space Group gets rendered
      assert render(view) =~ "Collaborative Space"
    end

    test "shows course setup recommendation for a section_created parameter",
         %{
           instructor: instructor,
           section: section,
           conn: conn
         } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live(conn, "#{live_view_manage_route(section.slug)}?section_created=true")

      assert has_element?(view, "#section-created-setup-card")

      assert has_element?(
               view,
               ~s{#section-created-url-cleanup[phx-hook="SectionCreatedUrlCleanup"]}
             )
    end

    test "does not show certificate settings link when certificates are disabled", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_manage_route(section.slug))

      refute has_element?(
               view,
               "a[href='/sections/#{section.slug}/certificate_settings']",
               "Manage Certificate Settings"
             )
    end

    test "shows template label for sections created from a template", %{
      instructor: instructor,
      conn: conn
    } do
      template = insert(:section, type: :blueprint)

      section =
        insert(:section,
          type: :enrollable,
          blueprint_id: template.id
        )

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, live_view_manage_route(section.slug))

      assert has_element?(view, "label", "Template")
      refute has_element?(view, "label", "Product")
    end
  end

  describe "admin" do
    setup [:admin_conn]

    test "can access certificate settings when certificates are disabled", %{conn: conn} do
      section =
        insert(:section, %{certificate_enabled: false, open_and_free: true, type: :enrollable})

      {:ok, view, _html} = live(conn, live_view_manage_route(section.slug))

      assert has_element?(
               view,
               "a[href='/sections/#{section.slug}/certificate_settings']",
               "Manage Certificate Settings"
             )
    end
  end
end
