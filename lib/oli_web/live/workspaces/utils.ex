defmodule OliWeb.Workspace.Utils do
  @moduledoc """
    Utility functions for workspace components.
  """
  use OliWeb, :html

  import OliWeb.Components.Utils

  alias Phoenix.LiveView.JS
  alias OliWeb.Workspace.SubMenuItem
  alias OliWeb.Icons

  attr :hierarchy, :list
  attr :sidebar_expanded, :boolean, default: true
  attr :active_view, :atom, default: nil
  attr :active_workspace, :atom, default: nil
  attr :slug, :string
  attr :title, :string

  def sub_menu(assigns) do
    ~H"""
    <.title {assigns} />
    <div class="w-full p-2 flex-col justify-center gap-2 items-center inline-flex">
      <.sub_menu_item
        :for={sub_menu_item <- @hierarchy}
        sub_menu_item={sub_menu_item}
        sidebar_expanded={@sidebar_expanded}
        active_view={@active_view}
        active_workspace={@active_workspace}
        slug={@slug}
      />
    </div>
    """
  end

  attr :current_item, :string, default: nil
  attr :target_to_expand, :string, default: nil
  attr :sidebar_expanded, :boolean, default: true
  attr :active_view, :atom, default: nil
  attr :active_workspace, :atom, default: nil
  attr :slug, :string
  attr :sub_menu_item, :map

  def sub_menu_item(%{sub_menu_item: %SubMenuItem{children: []} = item} = assigns) do
    base_module =
      case assigns.active_workspace do
        :course_author -> OliWeb.Workspaces.CourseAuthor
        :instructor -> OliWeb.Workspaces.Instructor
        :student -> OliWeb.Workspaces.Student
        _ -> raise "Unknown workspace: #{assigns.active_workspace}"
      end

    item_view = item.view |> Atom.to_string() |> Macro.camelize()

    view_module =
      Module.concat([base_module, item_view <> "Live"])

    assigns = assign(assigns, item: item, view_module: view_module)

    ~H"""
    <.link
      navigate={
        Routes.live_path(OliWeb.Endpoint, @view_module, @slug, sidebar_expanded: @sidebar_expanded)
      }
      class={["w-full h-[35px] flex-col justify-center items-center flex hover:no-underline"]}
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
    expanded = assigns[:current_item] == item.text
    item_id = item.text |> String.downcase() |> String.replace(" ", "_")

    assigns =
      assign(assigns, item: item, item_id: item_id, children: children, expanded: expanded)

    ~H"""
    <div class="w-full relative">
      <.button
        id={"button_for_#{@item.parent_view}"}
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
        class={"pl-4 #{if @expanded || active_view_in_children?(@item.children, @active_view), do: "block", else: "hidden"} #{if !@sidebar_expanded, do: "absolute top-0 left-12 bg-white dark:bg-[#222126] pl-0 rounded-md"}"}
        phx-click-away={!@sidebar_expanded && JS.hide(to: "##{@item_id}_children")}
      >
        <.sub_menu_item
          :for={child <- @children}
          sub_menu_item={child}
          sidebar_expanded={@sidebar_expanded}
          current_item={@item.text}
          target_to_expand={"#{@item_id}_children"}
          active_workspace={@active_workspace}
          active_view={@active_view}
          slug={@slug}
        />
      </div>
    </div>
    """
  end

  attr :is_active, :boolean, default: false
  attr :sidebar_expanded, :boolean, default: true
  attr :badge, :integer, default: nil
  attr :on_active_bg, :string, default: "bg-zinc-400 bg-opacity-20"
  attr :sub_menu_item, :map
  attr :active_view, :atom, default: nil

  def nav_link_content(assigns) do
    item_id = assigns.sub_menu_item.text |> String.downcase() |> String.replace(" ", "_")
    assigns = assign(assigns, :item_id, item_id)

    ~H"""
    <div class={[
      "relative w-full h-9 px-3 py-3 dark:hover:bg-[#141416] hover:bg-zinc-400/10 rounded-lg justify-start items-center gap-3 inline-flex",
      if(@is_active,
        do: @on_active_bg
      )
    ]}>
      <div :if={@sub_menu_item.icon} class="w-5 h-5 flex items-center justify-center">
        <%= apply(Icons, String.to_existing_atom(@sub_menu_item.icon), [assigns]) %>
      </div>
      <div class={[
        "text-[#757682] dark:text-[#BAB8BF] text-sm font-medium tracking-tight flex flex-row justify-between",
        if(@is_active, do: "!font-semibold dark:!text-white !text-[#353740]")
      ]}>
        <div
          :if={@sidebar_expanded or not is_nil(@sub_menu_item.parent_view)}
          class="whitespace-nowrap"
        >
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
  attr :title, :string, default: nil

  def title(assigns) do
    ~H"""
    <div class="w-full">
      <%= if @sidebar_expanded do %>
        <h2 class="truncate text-[14px] h-[24px] font-bold ml-5 dark:text-[#B8B4BF] text-[#353740] tracking-[-1%] leading-6 uppercase">
          <%= @title %>
        </h2>
      <% else %>
        <div class="w-9 m-auto border border-zinc-500"></div>
      <% end %>
    </div>
    """
  end

  defp active_view_in_children?(children, active_view) do
    Enum.any?(children, fn child -> child.view == active_view end)
  end

  def hierarchy(:course_author) do
    [
      %SubMenuItem{
        text: "Overview",
        icon: "author_overview",
        view: :overview,
        parent_view: nil,
        children: [],
        class: ""
      },
      %SubMenuItem{
        text: "Create",
        icon: "author_create",
        view: :create,
        parent_view: nil,
        children: [
          %SubMenuItem{
            text: "Objectives",
            icon: nil,
            view: :objectives,
            parent_view: :create,
            children: [],
            class: ""
          },
          %SubMenuItem{
            text: "Activity Bank",
            icon: nil,
            view: :activity_bank,
            parent_view: :create,
            children: [],
            class: ""
          },
          %SubMenuItem{
            text: "Experiments",
            icon: nil,
            view: :experiments,
            parent_view: :create,
            children: [],
            class: ""
          },
          %SubMenuItem{
            text: "Bibliography",
            icon: nil,
            view: :bibliography,
            parent_view: :create,
            children: [],
            class: ""
          },
          %SubMenuItem{
            text: "Curriculum",
            icon: nil,
            view: :curriculum,
            parent_view: :create,
            children: [],
            class: ""
          },
          %SubMenuItem{
            text: "All Pages",
            icon: nil,
            view: :pages,
            parent_view: :create,
            children: [],
            class: ""
          },
          %SubMenuItem{
            text: "All Activities",
            icon: nil,
            view: :activities,
            parent_view: :create,
            children: [],
            class: ""
          }
        ],
        class: ""
      },
      %SubMenuItem{
        text: "Publish",
        icon: "author_publish",
        view: :author_publish,
        parent_view: nil,
        children: [
          %SubMenuItem{
            text: "Review",
            icon: nil,
            view: :review,
            parent_view: :author_publish,
            children: [],
            class: ""
          },
          %SubMenuItem{
            text: "Publish",
            icon: nil,
            view: :publish,
            parent_view: :author_publish,
            children: [],
            class: ""
          },
          %SubMenuItem{
            text: "Products",
            icon: nil,
            view: :products,
            parent_view: :author_publish,
            children: [],
            class: ""
          }
        ],
        class: ""
      },
      %SubMenuItem{
        text: "Improve",
        icon: "author_improve",
        view: :improve,
        parent_view: nil,
        children: [
          %SubMenuItem{
            text: "Insights",
            icon: nil,
            view: :insights,
            parent_view: :improve,
            children: [],
            class: ""
          }
        ],
        class: ""
      }
    ]
  end

  def hierarchy(:instructor) do
    []
  end

  def hierarchy(:student) do
    []
  end
end
