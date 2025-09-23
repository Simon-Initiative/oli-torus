defmodule OliWeb.LmsUserInstructionsLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Lti_1p3.Roles.ContextRoles

  describe "show" do
    setup %{conn: conn} do
      user = insert(:user, independent_learner: false)
      {:ok, conn: log_in_user(conn, user), user: user}
    end

    test "renders enrolled LTI course titles and logout link", %{conn: conn, user: user} do
      lti_section_1 = insert(:section, title: "Alpha LTI Course")
      lti_section_2 = insert(:section, title: "Beta LTI Course")

      Sections.enroll(user.id, lti_section_1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user.id, lti_section_2.id, [ContextRoles.get_role(:context_learner)])

      {:ok, _view, html} =
        live(
          conn,
          ~p"/lms_user_instructions?#{[section_title: "Independent Course", request_path: "/sections/independent/enroll"]}"
        )

      assert html =~ "Account Type Mismatch"
      assert html =~ "Alpha LTI Course, Beta LTI Course"
      assert html =~ "Independent Course"

      {:ok, document} = Floki.parse_document(html)

      logout_href =
        document |> Floki.find("#lms_user_warning a") |> Floki.attribute("href") |> List.first()

      assert logout_href == "/users/log_out?request_path=%2Fsections%2Findependent%2Fenroll"
    end

    test "falls back to default logout path when request path missing", %{conn: conn, user: user} do
      section = insert(:section, title: "Gamma LTI Course")
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, _view, html} =
        live(conn, ~p"/lms_user_instructions?#{[section_title: "Independent Course"]}")

      {:ok, document} = Floki.parse_document(html)

      logout_href =
        document |> Floki.find("#lms_user_warning a") |> Floki.attribute("href") |> List.first()

      assert logout_href == "/users/log_out"
    end
  end

  test "redirects to home when no current user", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/lms_user_instructions")
  end
end
