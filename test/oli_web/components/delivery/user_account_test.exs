defmodule OliWeb.Components.Delivery.UserAccountTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.UserAccount
  alias OliWeb.Common.SessionContext
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Section

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

  defp build_ctx(user) do
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
      section: nil
    }
  end
end
