defmodule OliWeb.Admin.AdminRoleBoundariesTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Accounts
  alias Oli.Accounts.SystemRole

  @account_admin_message "You must be an account admin to access this page."
  @system_admin_message "You must be a system admin to access this page."

  # Live navigation never runs router plugs. These tests drive the client-side
  # navigation message directly (as a crafted link in the browser would) and
  # assert that role-restricted admin LiveViews still reject authors without
  # the required role.

  describe "content admin" do
    setup [:content_admin_conn]

    test "cannot load the user detail page directly", %{conn: conn} do
      user = insert(:user)

      assert {:error, {:redirect, %{to: "/workspaces/course_author", flash: flash}}} =
               live(conn, ~p"/admin/users/#{user.id}")

      assert flash["error"] == @account_admin_message
    end

    test "cannot live navigate from the admin portal to the user detail page", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(conn, ~p"/admin")

      assert_forced_reload_rejected(
        conn,
        live_redirect(view, to: ~p"/admin/users/#{user.id}"),
        @account_admin_message
      )
    end

    test "cannot live navigate from the admin portal to a system admin page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin")

      assert_forced_reload_rejected(
        conn,
        live_redirect(view, to: ~p"/admin/api_keys"),
        @system_admin_message
      )
    end
  end

  describe "account admin" do
    setup [:account_admin_conn]

    test "can live navigate between account admin pages", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      assert {:ok, _view, _html} = live_redirect(view, to: ~p"/admin/authors")
    end

    for path <- ["/admin/api_keys", "/admin/features", "/admin/restore_progress"] do
      test "cannot live navigate from an account admin page to #{path}", %{conn: conn} do
        {:ok, view, _html} = live(conn, ~p"/admin/users")

        assert_forced_reload_rejected(
          conn,
          live_redirect(view, to: unquote(path)),
          @system_admin_message
        )
      end
    end

    test "is rejected on live navigation within the session after losing the role", %{
      conn: conn,
      account_admin: account_admin
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      {:ok, _author} =
        Accounts.update_author(account_admin, %{
          system_role_id: SystemRole.role_id().content_admin
        })

      result = live_redirect(view, to: ~p"/admin/authors")

      assert {:error, {:redirect, %{to: "/workspaces/course_author"}}} = result
      assert {:ok, conn} = follow_redirect(result, conn)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == @account_admin_message
    end
  end

  describe "locked account admin" do
    setup [:account_admin_conn]

    test "is rejected on live navigation within the session after being locked", %{
      conn: conn,
      account_admin: account_admin
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      {:ok, _author} = Accounts.lock_author(account_admin)

      result = live_redirect(view, to: ~p"/admin/authors")

      assert {:error, {:redirect, %{to: "/authors/log_in"}}} = result
      assert {:ok, conn} = follow_redirect(result, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Your account has been locked. Please contact support for assistance."
    end
  end

  describe "system admin" do
    setup [:admin_conn]

    test "can live navigate between system admin pages", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/audit_log")

      assert {:ok, _view, _html} = live_redirect(view, to: ~p"/admin/api_keys")
    end

    test "can reach account admin pages through the forced reload", %{conn: conn} do
      user = insert(:user)
      {:ok, view, _html} = live(conn, ~p"/admin")

      assert {:error, {:redirect, %{to: to}}} =
               live_redirect(view, to: ~p"/admin/users/#{user.id}")

      assert {:ok, detail_view, _html} = live(conn, URI.parse(to).path)

      # Let the pending invitations async assign finish before the test owner exits.
      render_async(detail_view)
    end
  end

  describe "author without an admin role" do
    setup [:author_conn]

    test "cannot live navigate from an authoring page to the admin portal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/authoring/projects")

      assert {:error, {:redirect, %{to: to}}} = live_redirect(view, to: ~p"/admin")

      conn = get(conn, URI.parse(to).path)

      assert redirected_to(conn) == ~p"/workspaces/course_author"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You are not authorized to access this page."
    end
  end

  describe "visitor without a session" do
    test "cannot live navigate from a public page to an admin page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sections/join/invalid")

      assert {:error, {:redirect, %{to: to}}} =
               live_redirect(view, to: ~p"/admin/restore_progress")

      conn = get(conn, URI.parse(to).path)

      assert redirected_to(conn) =~ "/authors/log_in"
    end
  end

  # Crossing into another live_session forces a full page load, so the router
  # pipeline runs again and rejects the author.
  defp assert_forced_reload_rejected(conn, live_redirect_result, message) do
    assert {:error, {:redirect, %{to: to}}} = live_redirect_result

    conn = get(conn, URI.parse(to).path)

    assert redirected_to(conn) == ~p"/workspaces/course_author"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == message
  end
end
