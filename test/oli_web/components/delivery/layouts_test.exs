defmodule OliWeb.Components.Delivery.LayoutsTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.Layouts
  alias OliWeb.Common.SessionContext
  alias Oli.Delivery.Sections.Section
  alias Oli.Authoring.Course.Project
  alias Oli.Accounts.User
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias OliWeb.Workspaces.SubMenuItem
  alias OliWeb.Workspaces.Utils, as: WorkspaceUtils

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

    test "renders logos with descriptive alt text" do
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

      html = render_component(&Layouts.header/1, assigns)

      assert html =~ ~s(alt="OLI Torus logo")
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

  describe "template_preview_banner/1" do
    test "renders preview banner with exit action when template preview mode is active" do
      html =
        render_component(&Layouts.template_preview_banner/1, %{
          template_preview_mode: true,
          template_preview_exit_path: "/authoring/template_preview/exit"
        })

      assert html =~ "Preview Mode"
      assert html =~ "Exit Preview"
      assert html =~ "/authoring/template_preview/exit"
      assert html =~ "bg-[#deecff]"
      assert html =~ "border-[#8ab8e5]"
    end

    test "does not render when template preview mode is inactive" do
      assert render_component(&Layouts.template_preview_banner/1, %{
               template_preview_mode: false,
               template_preview_exit_path: nil
             }) =~ ""
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

  describe "sidebar_nav/1" do
    test "renders mobile menu as a full-screen overlay with settings" do
      assigns = %{
        ctx: %SessionContext{
          user: %User{id: 1, name: "Test User", platform_roles: []},
          browser_timezone: "America/Montevideo",
          is_liveview: true,
          author: nil,
          local_tz: "America/Montevideo"
        },
        is_admin: false,
        section: %Section{
          id: 1,
          title: "Test Section",
          slug: "test-section",
          brand: nil,
          lti_1p3_deployment: nil
        },
        active_tab: :index,
        sidebar_expanded: true,
        notes_enabled: false,
        discussions_enabled: false,
        preview_mode: false,
        has_scheduled_resources?: false,
        notification_badges: %{}
      }

      html = render_component(&Layouts.sidebar_nav/1, assigns)

      assert html =~ ~s(id="mobile-nav-menu")
      assert html =~ "fixed"
      assert html =~ "inset-0"
      assert html =~ "h-[100dvh]"
      assert html =~ ~s(aria-label="Close menu")
      assert html =~ ~s(aria-label="Settings")
      assert html =~ "Exit Course"
    end
  end

  describe "workspace_sidebar_nav/1" do
    test "renders mobile menu as a full-screen overlay with settings" do
      assigns = %{
        ctx: %SessionContext{
          user: %User{id: 1, name: "Test User", platform_roles: []},
          browser_timezone: "America/Montevideo",
          is_liveview: true,
          author: nil,
          local_tz: "America/Montevideo"
        },
        is_admin: false,
        active_workspace: :student,
        active_view: nil,
        sidebar_expanded: true,
        preview_mode: false,
        section: %Section{
          id: 1,
          title: "Test Section",
          slug: "test-section",
          brand: nil,
          lti_1p3_deployment: nil
        },
        resource_title: "Workspace",
        resource_slug: nil,
        show_desktop: true
      }

      html = render_component(&Layouts.workspace_sidebar_nav/1, assigns)

      assert html =~ ~s(id="mobile-nav-menu")
      assert html =~ "fixed"
      assert html =~ "inset-0"
      assert html =~ "h-[100dvh]"
      assert html =~ ~s(aria-label="Close menu")
      assert html =~ ~s(aria-label="Settings")
      assert html =~ "Exit Course"
    end

    test "renders template update badge on Templates when sidebar is expanded" do
      assigns = %{
        hierarchy: [
          %SubMenuItem{
            text: "Publish",
            view: :author_publish,
            badge_key: :template_updates,
            children: [
              %SubMenuItem{text: "Review", view: :review, parent_view: :author_publish},
              %SubMenuItem{text: "Publish", view: :publish, parent_view: :author_publish},
              %SubMenuItem{
                text: "Templates",
                view: :products,
                parent_view: :author_publish,
                badge_key: :template_updates
              }
            ]
          }
        ],
        resource_slug: "project-slug",
        resource_title: "Project",
        active_workspace: :course_author,
        active_view: :products,
        sidebar_expanded: true,
        notification_badges: %{template_updates: 13}
      }

      html = render_component(&WorkspaceUtils.sub_menu/1, assigns)

      assert html =~ "Templates"
      assert Regex.match?(~r/>\s*13\s*<\/span>/, html)
      assert length(Regex.scan(~r/>\s*13\s*<\/span>/, html)) == 1
    end

    test "renders template update badge on Publish when sidebar is collapsed" do
      assigns = %{
        hierarchy: [
          %SubMenuItem{
            text: "Publish",
            view: :author_publish,
            badge_key: :template_updates,
            children: [
              %SubMenuItem{text: "Review", view: :review, parent_view: :author_publish},
              %SubMenuItem{text: "Publish", view: :publish, parent_view: :author_publish},
              %SubMenuItem{
                text: "Templates",
                view: :products,
                parent_view: :author_publish,
                badge_key: :template_updates
              }
            ]
          }
        ],
        resource_slug: "project-slug",
        resource_title: "Project",
        active_workspace: :course_author,
        active_view: :overview,
        sidebar_expanded: false,
        notification_badges: %{template_updates: 13}
      }

      html = render_component(&WorkspaceUtils.sub_menu/1, assigns)

      assert html =~ "button_for_author_publish"
      assert Regex.match?(~r/>\s*13\s*<\/span>/, html)
      assert length(Regex.scan(~r/>\s*13\s*<\/span>/, html)) == 1
    end
  end
end
