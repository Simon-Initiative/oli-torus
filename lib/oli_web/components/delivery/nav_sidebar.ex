defmodule OliWeb.Components.Delivery.NavSidebar do
  use Phoenix.Component
  use OliWeb, :verified_routes

  import OliWeb.Components.Delivery.Utils
  import Oli.Utils, only: [value_or: 2]
  import Oli.Branding

  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Resources.ResourceType
  alias Oli.Resources.Revision
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Branding.Brand
  alias OliWeb.Components.Delivery.UserAccountMenu
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias OliWeb.Common.SessionContext

  @container_type_id ResourceType.get_id_by_type("container")

  slot(:inner_block, required: true)

  def main_with_nav(assigns) do
    ~H"""
    <main role="main" class="flex-1 flex flex-col relative lg:flex-row">
      <.navbar {assigns} path_info={@conn.path_info} />

      <div class="flex-1 flex flex-col lg:pl-[200px]">
        <%= render_slot(@inner_block) %>
      </div>
    </main>
    """
  end

  attr(:context, SessionContext)
  attr(:path_info, :list)

  def navbar(assigns) do
    links =
      if is_preview_mode?(assigns),
        do: get_preview_links(assigns),
        else: get_links(assigns, assigns.path_info)

    assigns =
      assigns
      |> assign(:logo, logo_details(assigns))
      |> assign(:links, links)
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
        selectedTimezone: @selected_timezone,
        timezones: @timezones
      }) %>
    </div>
    """
  end

  defp get_preview_links(%{section: %Section{} = section} = assigns) do
    hierarchy = Sections.build_hierarchy(Oli.Repo.preload(section, [:root_section_resource]))

    home_map = %{
      name: "Home",
      href: ~p"/sections/#{section.slug}/preview/overview",
      active: is_active(assigns.path_info, :overview)
    }

    course_content_map = %{
      name: "Course Content",
      popout: %{
        component: "Components.CourseContentOutline",
        props: %{
          hierarchy: hierarchy,
          sectionSlug: section.slug,
          isPreview: true,
          displayItemNumbering: section.display_curriculum_item_numbering
        }
      },
      active: is_active(assigns.path_info, :content)
    }

    discussion_map = %{
      name: "Discussion",
      href: ~p"/sections/#{section.slug}/preview/discussion",
      active: is_active(assigns.path_info, :discussion)
    }

    assignments_map = %{
      name: "Assignments",
      href: ~p"/sections/#{section.slug}/preview/my_assignments",
      active: is_active(assigns.path_info, :assignments)
    }

    exploration_map = %{
      name: "Exploration",
      href: ~p"/sections/#{section.slug}/preview/exploration",
      active: is_active(assigns.path_info, :exploration)
    }

    practice_map = %{
      name: "Practice",
      href: ~p"/sections/#{section.slug}/preview/practice",
      active: is_active(assigns.path_info, :deliberate_practice)
    }

    [home_map, course_content_map] ++
      add_if(section.contains_discussions, discussion_map) ++
      [assignments_map] ++
      add_if(section.contains_explorations, exploration_map) ++
      add_if(section.contains_deliberate_practice, practice_map)
  end

  defp get_preview_links(%{project: %Project{} = project}) do
    hierarchy = translate_to_outline(AuthoringResolver.full_hierarchy(project.slug))

    [
      %{name: "Home", href: "#", active: false},
      %{
        name: "Course Content",
        popout: %{
          component: "Components.CourseContentOutline",
          props: %{
            hierarchy: hierarchy,
            sectionSlug: nil,
            projectSlug: project.slug,
            isPreview: true
          }
        },
        active: true
      },
      %{name: "Discussion", href: "#", active: false},
      %{name: "Assignments", href: "#", active: false}
    ]
  end

  defp get_links(%{section: section} = assigns, path_info) do
    hierarchy = Sections.build_hierarchy(Oli.Repo.preload(section, [:root_section_resource]))

    home_map = %{
      name: "Home",
      href: ~p"/sections/#{section.slug}/overview",
      active: is_active(path_info, :overview)
    }

    course_content_map = %{
      name: "Course Content",
      popout: %{
        component: "Components.CourseContentOutline",
        props: %{
          hierarchy: hierarchy,
          sectionSlug: section.slug,
          displayItemNumbering: section.display_curriculum_item_numbering
        }
      },
      active: is_active(path_info, :content)
    }

    discussion_map = %{
      name: "Discussion",
      href: ~p"/sections/#{section.slug}/discussion",
      active: is_active(path_info, :discussion)
    }

    assignments_map = %{
      name: "Assignments",
      href: ~p"/sections/#{section.slug}/my_assignments",
      active: is_active(path_info, :assignments)
    }

    exploration_map = %{
      name: "Exploration",
      href: ~p"/sections/#{section.slug}/exploration",
      active: is_active(path_info, :exploration)
    }

    practice_map = %{
      name: "Practice",
      href: ~p"/sections/#{section.slug}/practice",
      active: is_active(path_info, :deliberate_practice)
    }

    [home_map, course_content_map] ++
      add_if(assigns.section.contains_discussions, discussion_map) ++
      [assignments_map] ++
      add_if(assigns.section.contains_explorations, exploration_map) ++
      add_if(assigns.section.contains_deliberate_practice, practice_map)
  end

  defp add_if(true, element), do: [element]
  defp add_if(_nil_false, _element), do: []

  defp logo_details(assigns) do
    %{
      href:
        case assigns[:logo_link] do
          nil -> logo_link_path(assigns)
          logo_link -> logo_link
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

  defp is_active(["sections", _, "page", _], :content), do: true
  defp is_active(["sections", _, "container", _], :content), do: true
  defp is_active(["sections", _, "preview", "page", _], :content), do: true
  defp is_active(["sections", _, "preview", "container", _], :content), do: true

  defp is_active(path_info, path) do
    case {List.last(path_info), path} do
      {"overview", :overview} -> true
      {"exploration", :exploration} -> true
      {"discussion", :discussion} -> true
      {"practice", :deliberate_practice} -> true
      {"my_assignments", :assignments} -> true
      _ -> false
    end
  end

  defp translate_to_outline(%HierarchyNode{} = node) do
    case node do
      %{
        uuid: id,
        children: children,
        revision: %Revision{resource_type_id: @container_type_id, title: title, slug: slug}
      } ->
        # container
        %{
          type: "container",
          children: Enum.map(children, &translate_to_outline/1),
          title: title,
          id: id,
          slug: slug
        }

      %{
        uuid: id,
        revision: %Revision{title: title, slug: slug}
      } ->
        # page
        %{type: "page", title: title, id: id, slug: slug}
    end
  end
end
