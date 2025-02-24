defmodule OliWeb.Plugs.EnsureUserSectionVisitTest do
  use OliWeb.ConnCase
  import Oli.Factory

  alias OliWeb.Plugs.EnsureUserSectionVisit
  alias Oli.Delivery.Sections
  alias Lti_1p3.Tool.ContextRoles

  describe "ensure_user_section_visit/2" do
    setup %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, [])

      {:ok, conn: conn}
    end

    test "does not redirect when user is an admin", %{conn: conn} do
      user = user_fixture()

      conn = conn
             |> assign(:current_user, user)
             |> assign(:is_admin, true)

      assert conn == conn |> EnsureUserSectionVisit.call([])
    end

    test "does not redirect when user has visited the section", %{conn: conn} do
      user = insert(:user)
      section = insert(:section)

      conn = conn
             |> assign(:current_user, user)
             |> assign(:section, section)
             |> fetch_session()
             |> Plug.Conn.put_session("visited_sections", Map.put(%{}, section.slug, true))

      assert conn == conn |> EnsureUserSectionVisit.call([])
    end

    test "redirects to onboarding wizard when user has not visited the section", %{conn: conn} do
      user = insert(:user)
      section = insert(:section)

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = conn
             |> assign(:current_user, user)
             |> assign(:section, section)
             |> EnsureUserSectionVisit.call([])

      assert redirected_to(conn) == "/sections/#{section.slug}/welcome"
    end
  end
end
