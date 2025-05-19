defmodule OliWeb.Sections.LtiExternalToolsLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Lti_1p3.Roles.ContextRoles

  defp live_view_lti_external_tools_route(section_slug) do
    ~p"/sections/#{section_slug}/lti_external_tools"
  end

  defp create_elixir_project(_conn) do
    section = insert(:section, %{open_and_free: true, type: :enrollable})
    [section: section]
  end

  describe "instructor" do
    setup [:instructor_conn, :create_elixir_project]

    test "can access correctly", %{conn: conn, section: section, instructor: instructor} do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      {:ok, _view, html} = live(conn, live_view_lti_external_tools_route(section.slug))

      assert html =~ "LTI 1.3 External Tools"
    end
  end

  describe "admin" do
    setup [:admin_conn, :create_elixir_project]

    test "can access correctly", %{conn: conn, section: section} do
      {:ok, _view, html} = live(conn, live_view_lti_external_tools_route(section.slug))

      assert html =~ "LTI 1.3 External Tools"
    end
  end

  describe "student" do
    setup [:user_conn, :create_elixir_project]

    test "cannot access and gets redirected", %{conn: conn, section: section, user: user} do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:error, {:redirect, %{to: "/unauthorized", flash: %{}}}} =
        live(conn, live_view_lti_external_tools_route(section.slug))
    end
  end
end
