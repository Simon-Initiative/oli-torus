defmodule OliWeb.Components.Delivery.UserAccountTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias OliWeb.Components.Delivery.UserAccount
  alias OliWeb.Common.SessionContext
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Lti_1p3.Roles.ContextRoles

  describe "menu/1" do
    test "renders guest menu actions and preferences" do
      ctx = build_ctx(%User{guest: true, name: "Guest"})

      assigns = %{
        id: "user-account-menu",
        ctx: ctx,
        is_admin: false,
        section: %Section{slug: "s1"}
      }

      html = render_component(&UserAccount.menu/1, assigns)

      assert html =~ "Guest"
      assert html =~ "Theme"
      assert html =~ "Preferences"
      assert html =~ "Cookies"
      assert html =~ "Timezone"
      assert html =~ "Show Math Previews"
      assert html =~ "Create an Account"
      assert html =~ "Sign In"
      assert html =~ "/users/register"
      assert html =~ "/users/log_in"
    end

    test "renders student menu with account actions" do
      ctx =
        build_ctx(%User{
          name: "Jane Doe",
          email: "jane@example.com",
          independent_learner: true,
          email_confirmed_at: DateTime.utc_now()
        })

      assigns = %{
        id: "user-account-menu",
        ctx: ctx,
        is_admin: false,
        section: %Section{slug: "s1"}
      }

      html = render_component(&UserAccount.menu/1, assigns)

      assert html =~ "Account Settings"
      assert html =~ "My Courses"
      assert html =~ "Theme"
      assert html =~ "Preferences"
      assert html =~ "Cookies"
      assert html =~ "Timezone"
      assert html =~ "Sign Out"
    end
  end

  describe "workspace_menu/1" do
    test "routes My Courses to instructor workspace for users with instructor enrollments" do
      user = insert(:user, can_create_sections: false, independent_learner: true)
      section = insert(:section, status: :active)

      {:ok, _enrollment} =
        Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])

      html =
        render_component(&UserAccount.workspace_menu/1, %{
          id: "workspace-user-menu",
          ctx: build_ctx(user),
          is_admin: false,
          active_workspace: :instructor
        })

      assert html =~ ~s(href="/workspaces/instructor")
      assert html =~ "My Courses"
    end

    test "routes My Courses to student workspace when current section role is student" do
      user = insert(:user, can_create_sections: true, independent_learner: true)
      section = insert(:section, status: :active)

      {:ok, _enrollment} =
        Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      html =
        render_component(&UserAccount.workspace_menu/1, %{
          id: "workspace-user-menu",
          ctx: build_ctx(user, section),
          is_admin: false,
          active_workspace: :student
        })

      assert html =~ ~s(href="/workspaces/student")
      assert html =~ "My Courses"
    end
  end

  defp build_ctx(user, section \\ nil) do
    user =
      case Map.get(user, :platform_roles) do
        %Ecto.Association.NotLoaded{} -> %{user | platform_roles: []}
        nil -> %{user | platform_roles: []}
        _ -> user
      end

    %SessionContext{
      user: user,
      author: nil,
      browser_timezone: "UTC",
      local_tz: "UTC",
      is_liveview: true,
      section: section
    }
  end
end
