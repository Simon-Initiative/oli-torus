defmodule OliWeb.MasqueradeControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias Oli.Accounts
  alias Oli.Auditing
  alias Oli.Features

  setup %{conn: conn} do
    admin = insert(:author, system_role_id: Accounts.SystemRole.role_id().system_admin)
    user = insert(:user, independent_learner: true, can_create_sections: false)

    Features.change_state("admin-act-as-user", :enabled)

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> log_in_author(admin)

    {:ok, conn: conn, admin: admin, user: user}
  end

  test "renders confirmation page", %{conn: conn, user: user} do
    conn = get(conn, ~p"/admin/users/#{user.id}/act_as")

    assert html_response(conn, 200) =~ "Act as user confirmation"
    assert html_response(conn, 200) =~ user.email
  end

  test "starts masquerade and redirects to student landing page and audits", %{
    conn: conn,
    admin: admin,
    user: user
  } do
    conn = post(conn, ~p"/admin/masquerade/users/#{user.id}/start")

    assert redirected_to(conn) == "/workspaces/student"
    assert get_session(conn, :masquerade_active)
    assert get_session(conn, :masquerade_subject_id) == user.id
    assert get_session(conn, :masquerade_admin_author_id) == admin.id
    assert get_session(conn, :author_token) == nil
    assert is_binary(get_session(conn, :masquerade_original_author_token))

    [event] = Auditing.list_events(event_type: :masquerade_started, limit: 1)
    assert event.author_id == admin.id
    assert event.details["subject_id"] == user.id
  end

  test "admin is treated as logged out while masquerading", %{conn: conn, user: user} do
    conn =
      conn
      |> post(~p"/admin/masquerade/users/#{user.id}/start")
      |> recycle()
      |> get(~p"/")

    assert conn.assigns.current_author == nil
  end

  test "stops masquerade and restores session", %{conn: conn, admin: admin, user: user} do
    original_user_id = get_session(conn, :current_user_id)

    conn =
      conn
      |> post(~p"/admin/masquerade/users/#{user.id}/start")
      |> recycle()
      |> delete(~p"/admin/masquerade")

    assert redirected_to(conn) == "/admin/users/#{user.id}"
    refute get_session(conn, :masquerade_active)
    assert get_session(conn, :current_user_id) == original_user_id
    assert get_session(conn, :current_author_id) == admin.id

    [event] = Auditing.list_events(event_type: :masquerade_stopped, limit: 1)
    assert event.author_id == admin.id
    assert event.details["subject_id"] == user.id
  end

  test "starts masquerade for a non-independent learner user", %{conn: conn} do
    user = insert(:user, independent_learner: false, can_create_sections: false)

    conn = post(conn, ~p"/admin/masquerade/users/#{user.id}/start")

    assert redirected_to(conn) == "/workspaces/student"
    assert get_session(conn, :masquerade_subject_id) == user.id
  end

  test "starts masquerade and redirects to instructor landing for section creators", %{conn: conn} do
    user = insert(:user, independent_learner: false, can_create_sections: true)

    conn = post(conn, ~p"/admin/masquerade/users/#{user.id}/start")

    assert redirected_to(conn) == "/workspaces/instructor"
  end
end
