defmodule OliWeb.Components.Delivery.LayoutsTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.Layouts
  alias OliWeb.Common.SessionContext
  alias Oli.Delivery.Sections.Section
  alias Oli.Authoring.Course.Project
  alias Oli.Accounts.User
  alias Oli.Resources.Collaboration.CollabSpaceConfig

  describe "header/1" do
    test "renders header with logo if include_logo is true" do
      assigns = %{
        include_logo: true,
        preview_mode: false,
        section: %Section{id: 1, brand: nil, lti_1p3_deployment: nil},
        ctx: %SessionContext{
          user: %User{id: 1},
          browser_timezone: "America/Montevideo",
          is_liveview: true,
          author: nil,
          local_tz: "America/Montevideo"
        },
        sidebar_expanded: true,
        is_admin: true
      }

      assert render_component(&Layouts.header/1, assigns) =~ "header_logo_button"
    end
  end

  describe "title/1" do
    test "renders resource title if provided" do
      assigns = %{resource_title: "Test Resource", rest: %{class: "custom-class"}}
      assert render_component(&Layouts.title/1, assigns) =~ "Test Resource"
      assert render_component(&Layouts.title/1, assigns) =~ "custom-class"
    end

    test "renders section title if provided" do
      assigns = %{
        section: %Section{title: "Test Section", brand: nil, lti_1p3_deployment: nil},
        rest: %{class: "custom-class"},
        preview_mode: false
      }

      assert render_component(&Layouts.title/1, assigns) =~ "Test Section"
      assert render_component(&Layouts.title/1, assigns) =~ "custom-class"
    end

    test "appends '(Preview Mode)' when preview_mode is true" do
      assigns = %{
        section: %Section{title: "Test Section", brand: nil, lti_1p3_deployment: nil},
        preview_mode: true,
        rest: %{class: "custom-class"}
      }

      assert render_component(&Layouts.title/1, assigns) =~ "Test Section (Preview Mode)"
    end

    test "renders project title if provided" do
      assigns = %{project: %Project{title: "Test Project"}, rest: %{class: "custom-class"}}
      assert render_component(&Layouts.title/1, assigns) =~ "Test Project"
      assert render_component(&Layouts.title/1, assigns) =~ "custom-class"
    end

    test "does not render anything if no title is provided" do
      assigns = %{rest: %{class: "custom-class"}}
      assert render_component(&Layouts.title/1, assigns) == "\n\n"
    end
  end

  describe "user_given_name/1" do
    test "returns 'Guest' if user is a guest" do
      ctx = %SessionContext{
        user: %User{guest: true},
        browser_timezone: "America/Montevideo",
        is_liveview: true,
        author: nil,
        local_tz: "America/Montevideo"
      }

      assert Layouts.user_given_name(ctx) == "Guest"
    end

    test "returns user's given_name if user is present" do
      ctx = %SessionContext{
        user: %User{id: 1, given_name: "John"},
        browser_timezone: "America/Montevideo",
        is_liveview: true,
        author: nil,
        local_tz: "America/Montevideo"
      }

      assert Layouts.user_given_name(ctx) == "John"
    end
  end

  describe "user_name/1" do
    test "returns 'Guest' if user is a guest" do
      ctx = %SessionContext{
        user: %User{guest: true},
        browser_timezone: "America/Montevideo",
        is_liveview: true,
        author: nil,
        local_tz: "America/Montevideo"
      }

      assert Layouts.user_name(ctx) == "Guest"
    end

    test "returns user's name if user is present" do
      ctx = %SessionContext{
        user: %User{name: "John Doe"},
        browser_timezone: "America/Montevideo",
        is_liveview: true,
        author: nil,
        local_tz: "America/Montevideo"
      }

      assert Layouts.user_name(ctx) == "John Doe"
    end
  end

  describe "show_collab_space?/1" do
    test "returns false if config is nil" do
      assert Layouts.show_collab_space?(nil) == false
    end

    test "returns false if status is disabled" do
      assert Layouts.show_collab_space?(%CollabSpaceConfig{status: :disabled}) == false
    end

    test "returns true otherwise" do
      assert Layouts.show_collab_space?(%CollabSpaceConfig{status: :enabled}) == true
    end
  end
end
