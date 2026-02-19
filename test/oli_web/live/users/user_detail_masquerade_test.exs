defmodule OliWeb.Users.UserDetailMasqueradeTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Accounts
  alias Oli.Features

  setup %{conn: conn} do
    admin = insert(:author, system_role_id: Accounts.SystemRole.role_id().system_admin)
    user = insert(:user, independent_learner: true)

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> log_in_author(admin)

    {:ok, conn: conn, user: user}
  end

  test "shows act as user action when feature is enabled", %{conn: conn, user: user} do
    Features.change_state("admin-act-as-user", :enabled)

    {:ok, view, _html} = live(conn, ~p"/admin/users/#{user.id}")

    assert has_element?(view, "a", "Act as user")
  end

  test "does not show act as user action when feature is disabled", %{conn: conn, user: user} do
    Features.change_state("admin-act-as-user", :disabled)

    {:ok, view, _html} = live(conn, ~p"/admin/users/#{user.id}")

    refute has_element?(view, "a", "Act as user")
  end

  test "shows act as user action for non-independent learner when feature is enabled", %{
    conn: conn
  } do
    user = insert(:user, independent_learner: false)
    Features.change_state("admin-act-as-user", :enabled)

    {:ok, view, _html} = live(conn, ~p"/admin/users/#{user.id}")

    assert has_element?(view, "a", "Act as user")
  end
end
