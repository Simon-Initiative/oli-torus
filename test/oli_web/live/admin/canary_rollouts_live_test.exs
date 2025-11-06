defmodule OliWeb.Admin.CanaryRolloutsLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Accounts.SystemRole
  alias Oli.ScopedFeatureFlags.Rollouts

  @feature "canary_test_feature"

  describe "access control" do
    test "redirects unauthenticated visitors", %{conn: conn} do
      conn = get(conn, ~p"/admin/canary_rollouts")
      assert redirected_to(conn) == ~p"/authors/log_in"
    end

    test "blocks non-system admins", %{conn: conn} do
      author = insert(:author)
      conn = Plug.Test.init_test_session(conn, %{})

      {:error, {:redirect, %{to: "/workspaces/course_author", flash: flash}}} =
        conn
        |> log_in_author(author)
        |> live(~p"/admin/canary_rollouts")

      assert flash["error"] =~ "You are not authorized"
    end

    test "allows system admin to view dashboard", %{conn: conn} do
      admin = insert(:author, system_role_id: SystemRole.role_id().system_admin)

      {:ok, _view, html} =
        conn
        |> log_in_author(admin)
        |> live(~p"/admin/canary_rollouts")

      assert html =~ "Incremental Feature Rollout"
      assert html =~ "Make Changes"
    end
  end

  describe "editing rollouts" do
    setup %{conn: conn} do
      admin = insert(:author, system_role_id: SystemRole.role_id().system_admin)
      conn = log_in_author(conn, admin)

      # Ensure default rollout is off
      Rollouts.delete_rollout(@feature, :global, nil, admin, [])

      {:ok, conn: conn, admin: admin}
    end

    test "toggles edit mode and updates global stage", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/canary_rollouts")

      initial_html = render(view)
      assert initial_html =~ "Make Changes"
      refute initial_html =~ "Finish Changes"

      view
      |> element("button", "Make Changes")
      |> render_click()

      editing_html = render(view)
      assert editing_html =~ "Finish Changes"

      view
      |> element(
        "button[phx-value-feature='#{@feature}'][phx-value-scope_type='global'][phx-value-stage='internal_only']"
      )
      |> render_click()

      assert Rollouts.get_rollout(@feature, :global, nil).stage == :internal_only

      view
      |> element("button", "Finish Changes")
      |> render_click()

      final_html = render(view)
      assert final_html =~ "Make Changes"
      refute final_html =~ "Finish Changes"
    end
  end
end
