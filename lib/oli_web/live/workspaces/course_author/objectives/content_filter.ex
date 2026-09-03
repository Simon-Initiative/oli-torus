defmodule OliWeb.Workspaces.CourseAuthor.Objectives.ContentFilter do
  use OliWeb, :html

  alias Oli.Resources.ResourceType
  alias OliWeb.Icons

  attr :nodes, :list, required: true
  attr :selected_ids, :any, default: MapSet.new()
  attr :active_count, :integer, default: 0
  attr :open, :boolean, default: false
  attr :disabled, :boolean, default: false

  def render(assigns) do
    assigns =
      assigns
      |> assign(:nodes_by_id, Map.new(assigns.nodes, &{&1.resource_id, &1}))
      |> assign(:root_nodes, Enum.filter(assigns.nodes, &(&1.parent_ids == [])))

    ~H"""
    <div class="relative" id="course-content-filter">
      <button
        type="button"
        id="course-content-filter-trigger"
        class={[
          "inline-flex h-9 items-center gap-1.5 rounded-md border px-3 text-[13px] font-semibold leading-[19.5px] text-Text-text-high transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary",
          if(@open or @active_count > 0,
            do: "border-Fill-Buttons-fill-primary bg-Background-bg-primary",
            else: "border-Border-border-default bg-Background-bg-primary"
          ),
          @disabled && "cursor-not-allowed opacity-50"
        ]}
        aria-expanded={to_string(@open)}
        aria-controls="course-content-filter-menu"
        aria-label="Course content filter"
        disabled={@disabled}
        phx-click="toggle_course_content_filter"
      >
        Course content
        <span
          :if={@active_count > 0}
          class="rounded-full bg-Fill-Buttons-fill-primary px-1.5 py-0.5 text-[11px] leading-[11px] text-Text-text-white"
        >
          {@active_count}
        </span>
        <Icons.chevron_down
          width="9.5"
          height="5.5"
          variant="stroke"
          class={["ml-0.5 text-current transition-transform", @open && "rotate-180"]}
        />
      </button>

      <div
        :if={@open and not @disabled}
        id="course-content-filter-menu"
        role="dialog"
        aria-label="Course content filter options"
        phx-click-away={
          JS.push("close_course_content_filter") |> JS.focus(to: "#course-content-filter-trigger")
        }
        phx-window-keydown={
          JS.push("close_course_content_filter") |> JS.focus(to: "#course-content-filter-trigger")
        }
        phx-key="Escape"
        class="absolute right-0 z-50 mt-2 w-80 rounded-md border border-Border-border-default bg-Background-bg-secondary p-3 shadow-[0px_4px_12px_rgba(0,50,99,0.16)]"
      >
        <div class="mb-2 flex items-center justify-between gap-3">
          <h2 class="text-[13px] font-bold leading-[19.5px] text-Text-text-high">Course content</h2>
          <button
            :if={@active_count > 0}
            type="button"
            class="rounded px-1 text-xs font-semibold text-Text-text-button hover:text-Text-text-button focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
            phx-click="clear_course_content_filter"
          >
            Clear all
          </button>
        </div>

        <div
          id="course-content-filter-tree"
          role="tree"
          aria-label="Course content hierarchy"
          class="max-h-80 overflow-y-auto pr-1"
        >
          <%= for node <- @root_nodes do %>
            <.render_node
              node={node}
              level={0}
              nodes_by_id={@nodes_by_id}
              selected_ids={@selected_ids}
              visited_ids={MapSet.new()}
            />
          <% end %>
          <p :if={@root_nodes == []} class="py-4 text-sm text-Text-text-medium">
            No course content available.
          </p>
        </div>
      </div>
    </div>
    """
  end

  attr :node, :map, required: true
  attr :level, :integer, required: true
  attr :nodes_by_id, :map, required: true
  attr :selected_ids, :any, required: true
  attr :visited_ids, :any, required: true

  def render_node(assigns) do
    children =
      assigns.node.children
      |> Enum.reject(&MapSet.member?(assigns.visited_ids, &1))
      |> Enum.map(&Map.get(assigns.nodes_by_id, &1))
      |> Enum.reject(&is_nil/1)

    selected_ids = MapSet.new(assigns.selected_ids, &to_string/1)
    selected = MapSet.member?(selected_ids, to_string(assigns.node.resource_id))
    expandable? = children != []
    type = ResourceType.get_type_by_id(assigns.node.resource_type_id)
    visited_ids = MapSet.put(assigns.visited_ids, assigns.node.resource_id)

    assigns =
      assign(assigns,
        children: children,
        selected: selected,
        expandable?: expandable?,
        type: type,
        visited_ids: visited_ids
      )

    ~H"""
    <details
      id={"course-content-node-#{@node.resource_id}"}
      role="treeitem"
      open={@level == 0}
      aria-level={@level + 1}
      aria-expanded={if @expandable?, do: to_string(@level == 0), else: nil}
      class="group"
    >
      <summary class="flex min-w-0 list-none items-center gap-1 rounded px-1 py-1.5 text-sm text-Text-text-high marker:hidden focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary">
        <span
          class={["flex size-5 shrink-0 items-center justify-center", !@expandable? && "invisible"]}
          aria-hidden="true"
        >
          <Icons.chevron_down
            width="9.5"
            height="5.5"
            variant="stroke"
            class="text-Icon-icon-default transition-transform group-open:rotate-180"
          />
        </span>
        <input
          id={"course-content-checkbox-#{@node.resource_id}"}
          type="checkbox"
          checked={if @selected, do: "checked", else: nil}
          aria-checked={to_string(@selected)}
          aria-label={"Select #{@node.title}"}
          phx-click="toggle_course_content_item"
          phx-value-resource_id={@node.resource_id}
          class="size-4 shrink-0 rounded border-Border-border-default text-Fill-Buttons-fill-primary focus:ring-2 focus:ring-Fill-Buttons-fill-primary"
        />
        <span
          class="min-w-0 flex-1 truncate"
          title={@node.title}
          aria-label={"#{@type}: #{@node.title}"}
        >
          {@node.title}
        </span>
      </summary>
      <div :if={@expandable?} role="group" class="ml-5 border-l border-Border-border-default pl-2">
        <%= for child <- @children do %>
          <.render_node
            node={child}
            level={@level + 1}
            nodes_by_id={@nodes_by_id}
            selected_ids={@selected_ids}
            visited_ids={@visited_ids}
          />
        <% end %>
      </div>
    </details>
    """
  end
end
