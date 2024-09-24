defmodule OliWeb.Workspaces.Utils do
  @moduledoc """
    Utility functions for workspace components.
  """
  use OliWeb, :html

  import OliWeb.Components.Utils

  alias Phoenix.LiveView.JS
  alias OliWeb.Workspaces.SubMenuItem
  alias OliWeb.Icons

  attr :hierarchy, :list
  attr :sidebar_expanded, :boolean, default: true
  attr :active_view, :atom, default: nil
  attr :active_workspace, :atom, default: nil
  attr :resource_slug, :string
  attr :resource_title, :string

  def sub_menu(assigns) do
    ~H"""
    <div id="sub_menu">
      <.title {assigns} />
      <div class="w-full p-2 flex-col justify-center gap-2 items-center inline-flex">
        <.sub_menu_item
          :for={sub_menu_item <- @hierarchy}
          sub_menu_item={sub_menu_item}
          sidebar_expanded={@sidebar_expanded}
          active_view={@active_view}
          active_workspace={@active_workspace}
          resource_slug={@resource_slug}
        />
      </div>
    </div>
    """
  end

  attr :current_item, :string, default: nil
  attr :target_to_expand, :string, default: nil
  attr :sidebar_expanded, :boolean, default: true
  attr :active_view, :atom, default: nil
  attr :active_workspace, :atom, default: nil
  attr :resource_slug, :string
  attr :sub_menu_item, :map

  def sub_menu_item(%{sub_menu_item: %SubMenuItem{children: []} = item} = assigns) do
    %{
      active_workspace: active_workspace,
      resource_slug: resource_slug,
      sidebar_expanded: sidebar_expanded
    } = assigns

    route =
      build_route(active_workspace, resource_slug, item.parent_view, item.view, sidebar_expanded)

    assigns = assign(assigns, item: item, route: route)

    ~H"""
    <.link
      navigate={@route}
      class={["w-full flex-col justify-center items-center flex hover:no-underline"]}
    >
      <.nav_link_content
        is_active={@active_view == @item.view}
        sidebar_expanded={@sidebar_expanded}
        sub_menu_item={@item}
        active_view={@active_view}
      />
    </.link>
    """
  end

  def sub_menu_item(%{sub_menu_item: %SubMenuItem{children: children} = item} = assigns) do
    item_id = item.text |> String.downcase() |> String.replace(" ", "_")

    assigns =
      assign(assigns, item: item, item_id: item_id, children: children)

    ~H"""
    <div class="w-full relative">
      <.button
        id={"button_for_#{@item.view}"}
        class="w-full h-[35px] px-0 flex-col justify-center items-center flex hover:no-underline"
        phx-click={
          JS.toggle(to: "##{@item_id}_children")
          |> toggle_class("-rotate-90", to: "##{@item_id}_expand_icon")
          |> JS.remove_class("rotate-0", to: "##{@item_id}_expand_icon")
        }
      >
        <.nav_link_content
          is_active={@active_view == @item.view}
          sidebar_expanded={@sidebar_expanded}
          sub_menu_item={@item}
          active_view={@active_view}
        />
      </.button>
      <div
        role="expandable_submenu"
        id={"#{@item_id}_children"}
        class={"pl-4 #{if active_view_in_children?(@item.children, @active_view), do: "block", else: "hidden"} #{if !@sidebar_expanded, do: "absolute top-0 left-12 bg-white dark:bg-[#222126] pl-0 rounded-md"}"}
        phx-click-away={!@sidebar_expanded && JS.hide(to: "##{@item_id}_children")}
      >
        <.sub_menu_item
          :for={child <- @children}
          sub_menu_item={child}
          sidebar_expanded={@sidebar_expanded}
          target_to_expand={"#{@item_id}_children"}
          active_workspace={@active_workspace}
          active_view={@active_view}
          resource_slug={@resource_slug}
        />
      </div>
    </div>
    """
  end

  attr :is_active, :boolean, default: false
  attr :sidebar_expanded, :boolean, default: true
  attr :badge, :integer, default: nil
  attr :on_active_bg, :string, default: "bg-[#E6E9F2] dark:bg-[#202022]"
  attr :sub_menu_item, :map
  attr :active_view, :atom, default: nil

  def nav_link_content(assigns) do
    item_id = assigns.sub_menu_item.text |> String.downcase() |> String.replace(" ", "_")
    assigns = assign(assigns, :item_id, item_id)

    ~H"""
    <div class={[
      "w-full px-3 py-2 dark:hover:bg-[#404044] hover:bg-[#D9D9DD] rounded-lg justify-start items-center gap-3 inline-flex",
      if(@is_active, do: @on_active_bg)
    ]}>
      <div :if={@sub_menu_item.icon} class="w-5 flex items-center justify-center">
        <%= apply(Icons, String.to_existing_atom(@sub_menu_item.icon), [assigns]) %>
      </div>
      <div class={[
        "text-[#757682] dark:text-[#BAB8BF] text-sm font-medium tracking-tight flex flex-row justify-between",
        if(@is_active, do: "!font-semibold dark:!text-white !text-[#353740]")
      ]}>
        <div :if={@sidebar_expanded or not is_nil(@sub_menu_item.parent_view)} class="">
          <%= @sub_menu_item.text %>
        </div>

        <%= if @sidebar_expanded and @badge do %>
          <div>
            <.badge variant={:primary} class="ml-2"><%= @badge %></.badge>
          </div>
        <% end %>
      </div>
      <div :if={@sidebar_expanded and @sub_menu_item.children != []}>
        <div
          class={
            if !active_view_in_children?(@sub_menu_item.children, @active_view),
              do: "-rotate-90"
          }
          id={"#{@item_id}_expand_icon"}
          phx-mounted={
            if active_view_in_children?(@sub_menu_item.children, @active_view),
              do: JS.add_class("rotate-0") |> JS.show(to: "##{@item_id}_children")
          }
        >
          <Icons.chevron_down class="text-[#bab8bf]" />
        </div>
      </div>
    </div>
    """
  end

  attr :sidebar_expanded, :boolean, default: true
  attr :resource_title, :string, default: ""

  def title(assigns) do
    ~H"""
    <div class={"#{if @sidebar_expanded, do: "block", else: "hidden"} truncate text-[14px] h-[24px] font-bold ml-5 dark:text-[#B8B4BF] text-[#353740] tracking-[-1%] leading-6 uppercase"}>
      <%= @resource_title %>
    </div>
    """
  end

  defp active_view_in_children?(children, active_view) do
    Enum.any?(children, &(&1.view == active_view))
  end

  defp build_route(active_workspace, resource_slug, parent_view, view, sidebar_expanded) do
    {_, _, [route]} =
      case active_workspace do
        :course_author ->
          quote do:
                  sigil_p(
                    unquote(
                      "/workspaces/course_author/#{resource_slug}/#{view}?sidebar_expanded=#{sidebar_expanded}"
                    )
                  )

        :instructor ->
          if parent_view do
            quote do:
                    sigil_p(
                      unquote(
                        "/workspaces/instructor/#{resource_slug}/#{parent_view}/#{view}?sidebar_expanded=#{sidebar_expanded}"
                      )
                    )
          else
            quote do:
                    sigil_p(
                      unquote(
                        "/workspaces/instructor/#{resource_slug}/#{view}?sidebar_expanded=#{sidebar_expanded}"
                      )
                    )
          end
      end

    route
  end

  def hierarchy(:course_author) do
    [
      %SubMenuItem{
        text: "Overview",
        icon: "author_overview",
        view: :overview
      },
      %SubMenuItem{
        text: "Create",
        icon: "author_create",
        view: :create,
        children: [
          %SubMenuItem{
            text: "Objectives",
            view: :objectives,
            parent_view: :create
          },
          %SubMenuItem{
            text: "Activity Bank",
            view: :activity_bank,
            parent_view: :create
          },
          %SubMenuItem{
            text: "Experiments",
            view: :experiments,
            parent_view: :create
          },
          %SubMenuItem{
            text: "Bibliography",
            view: :bibliography,
            parent_view: :create
          },
          %SubMenuItem{
            text: "Curriculum",
            view: :curriculum,
            parent_view: :create
          },
          %SubMenuItem{
            text: "All Pages",
            view: :pages,
            parent_view: :create
          },
          %SubMenuItem{
            text: "All Activities",
            view: :activities,
            parent_view: :create
          }
        ]
      },
      %SubMenuItem{
        text: "Publish",
        icon: "author_publish",
        view: :author_publish,
        children: [
          %SubMenuItem{
            text: "Review",
            view: :review,
            parent_view: :author_publish
          },
          %SubMenuItem{
            text: "Publish",
            view: :publish,
            parent_view: :author_publish
          },
          %SubMenuItem{
            text: "Products",
            view: :products,
            parent_view: :author_publish
          }
        ]
      },
      %SubMenuItem{
        text: "Improve",
        icon: "author_improve",
        view: :improve,
        children: [
          %SubMenuItem{
            text: "Insights",
            view: :insights,
            parent_view: :improve
          }
        ]
      }
    ]
  end

  def hierarchy(:instructor) do
    [
      %SubMenuItem{
        text: "Overview",
        icon: "list_search",
        view: :overview,
        children: [
          %SubMenuItem{
            text: "Course Content",
            view: :course_content,
            parent_view: :overview
          },
          %SubMenuItem{
            text: "Students",
            view: :students,
            parent_view: :overview
          },
          %SubMenuItem{
            text: "Quiz Scores",
            view: :quiz_scores,
            parent_view: :overview
          },
          %SubMenuItem{
            text: "Recommended Actions",
            view: :recommended_actions,
            parent_view: :overview
          }
        ]
      },
      %SubMenuItem{
        text: "Insights",
        icon: "folder",
        view: :insights,
        children: [
          %SubMenuItem{
            text: "Content",
            view: :content,
            parent_view: :insights
          },
          %SubMenuItem{
            text: "Learning Objectives",
            view: :learning_objectives,
            parent_view: :insights
          },
          %SubMenuItem{
            text: "Scored Activities",
            view: :scored_activities,
            parent_view: :insights
          },
          %SubMenuItem{
            text: "Practice Activities",
            view: :practice_activities,
            parent_view: :insights,
            children: []
          },
          %SubMenuItem{
            text: "Surveys",
            view: :surveys,
            parent_view: :insights
          }
        ]
      },
      %SubMenuItem{
        text: "Manage",
        icon: "settings",
        view: :manage
      },
      %SubMenuItem{
        text: "Activity",
        icon: "message",
        view: :activity
      }
    ]
  end

  def hierarchy(:student) do
    []
  end
end
