defmodule OliWeb.Components.Delivery.NavSidebar do
  use Phoenix.Component

  import OliWeb.Components.Delivery.Utils
  import Oli.Utils, only: [value_or: 2]
  import Oli.Branding

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Branding.Brand
  alias OliWeb.Components.Delivery.UserAccountMenu
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section

  slot :inner_block, required: true

  def main_with_nav(assigns) do
    ~H"""
      <main role="main" class="h-screen flex flex-col relative lg:flex-row z-0">
        <.navbar {assigns} path_info={@conn.path_info} />

        <div class="flex-1 flex flex-col lg:pl-[200px] z-10">

          <%= render_slot(@inner_block) %>

        </div>
      </main>
    """
  end

  attr :path_info, :list

  def navbar(%{path_info: path_info} = assigns) do
    assigns =
      assigns
      |> assign(
        :logo,
        logo_details(assigns)
      )
      |> assign(
        :links,
        if is_preview_mode?(assigns) do
          get_preview_links(assigns[:section], path_info)
        else
          get_links(assigns, path_info)
        end
      )
      |> UserAccountMenu.user_account_menu_assigns()

    ~H"""
      <div id="navbar" phx-update="ignore">
        <%= ReactPhoenix.ClientSide.react_component("Components.Navbar", %{
          logo: @logo,
          links: @links,
          user: @user,
          preview: @preview,
          routes: @routes,
          sectionSlug: @section_slug,
          browserTimezone: @browser_timezone,
          defaultTimezone: @default_timezone,
          timezones: Enum.map(@timezones, &Tuple.to_list/1),
        }) %>
      </div>
    """
  end

  defp get_preview_links(%Section{contains_explorations: true}, path_info) do
    [
      %{
        name: "Home",
        href: "#",
        active: is_active(path_info, :overview)
      },
      %{name: "Course Content", href: "#", active: is_active(path_info, :content)},
      %{name: "Discussion", href: "#", active: is_active(path_info, :discussion)},
      %{name: "Assignments", href: "#", active: is_active(path_info, "")},
      %{
        name: "Exploration",
        href: "#",
        active: is_active(path_info, :exploration)
      }
    ]
  end

  defp get_preview_links(_, path_info) do
    [
      %{
        name: "Home",
        href: "#",
        active: is_active(path_info, :overview)
      },
      %{name: "Course Content", href: "#", active: is_active(path_info, :content)},
      %{name: "Discussion", href: "#", active: is_active(path_info, :discussion)},
      %{name: "Assignments", href: "#", active: is_active(path_info, "")}
    ]
  end

  defp get_links(%{section: %{contains_explorations: true}} = assigns, path_info) do
    hierarchy =
      assigns[:section]
      |> Oli.Repo.preload([:root_section_resource])
      |> Sections.build_hierarchy()

    [
      %{
        name: "Home",
        href: home_url(assigns),
        active: is_active(path_info, :overview)
      },
      %{
        name: "Course Content",
        popout: %{
          component: "Components.CourseContentOutline",
          props: %{hierarchy: hierarchy, sectionSlug: assigns[:section].slug}
        },
        active: is_active(path_info, :content)
      },
      %{
        name: "Discussion",
        href: discussion_url(assigns),
        active: is_active(path_info, :discussion)
      },
      %{name: "Assignments", href: "#", active: is_active(path_info, "")},
      %{
        name: "Exploration",
        href: exploration_url(assigns),
        active: is_active(path_info, :exploration)
      }
    ]
  end

  defp get_links(assigns, path_info) do
    hierarchy =
      assigns[:section]
      |> Oli.Repo.preload([:root_section_resource])
      |> Sections.build_hierarchy()

    [
      %{
        name: "Home",
        href: home_url(assigns),
        active: is_active(path_info, :overview)
      },
      %{
        name: "Course Content",
        popout: %{
          component: "Components.CourseContentOutline",
          props: %{hierarchy: hierarchy, sectionSlug: assigns[:section].slug}
        },
        active: is_active(path_info, :content)
      },
      %{
        name: "Discussion",
        href: discussion_url(assigns),
        active: is_active(path_info, :discussion)
      },
      %{name: "Assignments", href: "#", active: is_active(path_info, "")}
    ]
  end

  defp logo_details(assigns) do
    %{
      href:
        case assigns[:logo_link] do
          nil ->
            logo_link_path(assigns)

          logo_link ->
            logo_link
        end,
      src:
        case assigns do
          %{brand: %Brand{logo: logo, logo_dark: logo_dark}} ->
            %{light: logo, dark: value_or(logo_dark, logo)}

          _ ->
            %{
              light: brand_logo_url(assigns[:section]),
              dark: brand_logo_url_dark(assigns[:section])
            }
        end
    }
  end

  defp is_active(["sections", _, "overview"], :overview), do: true
  defp is_active(["sections", _, "exploration"], :exploration), do: true
  defp is_active(["sections", _, "discussion"], :discussion), do: true
  defp is_active(["sections", _, "page", _], :content), do: true
  defp is_active(["sections", _, "container", _], :content), do: true
  defp is_active(["sections", _, "preview", "overview"], :overview), do: true
  defp is_active(["sections", _, "preview", "exploration"], :exploration), do: true
  defp is_active(["sections", _, "preview", "discussion"], :discussion), do: true
  defp is_active(["sections", _, "preview", "page", _], :content), do: true
  defp is_active(["sections", _, "preview", "container", _], :content), do: true
  defp is_active(_, _), do: false

  defp home_url(assigns) do
    if assigns[:preview_mode] do
      Routes.live_path(
        OliWeb.Endpoint,
        OliWeb.Delivery.InstructorDashboard.ContentLive,
        assigns[:section_slug]
      )
    else
      Routes.page_delivery_path(OliWeb.Endpoint, :index, assigns[:section_slug])
    end
  end

  defp exploration_url(assigns) do
    if assigns[:preview_mode] do
      Routes.page_delivery_path(OliWeb.Endpoint, :exploration_preview, assigns[:section_slug])
    else
      Routes.page_delivery_path(OliWeb.Endpoint, :exploration, assigns[:section_slug])
    end
  end

  defp discussion_url(assigns) do
    if assigns[:preview_mode] do
      Routes.page_delivery_path(OliWeb.Endpoint, :discussion_preview, assigns[:section_slug])
    else
      Routes.page_delivery_path(OliWeb.Endpoint, :discussion, assigns[:section_slug])
    end
  end
end
