defmodule OliWeb.Components.Delivery.InstructorDashboard.DashboardSectionChrome do
  @moduledoc """
  Reusable chrome wrapper for instructor dashboard section groups.

  Responsibilities:
  - render shared section header/chrome container
  - expose section-level collapse/expand and reorder affordances
  - stay tile-agnostic (no section/tile business rules)
  """

  use OliWeb, :html

  attr :id, :string, required: true
  attr :section_id, :string, required: true
  attr :title, :string, required: true
  attr :expanded, :boolean, default: true
  attr :target, :any, default: nil
  attr :toggle_event, :string, default: "dashboard_section_toggled"
  attr :reorder_event, :string, default: "dashboard_sections_reordered"
  attr :move_label, :string, default: nil
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def section(assigns) do
    assigns = assign(assigns, :move_label, assigns.move_label || gettext("Move"))

    ~H"""
    <section
      id={@id}
      phx-hook="DashboardSectionChrome"
      data-dashboard-section-id={@section_id}
      data-reorder-event={@reorder_event}
      class={[
        "rounded border border-gray-200 bg-white shadow-sm transition-colors dark:border-gray-700 dark:bg-gray-800",
        @class
      ]}
    >
      <header class="flex items-center justify-between gap-3 border-b border-gray-100 px-4 py-3 dark:border-gray-700/70">
        <div class="flex min-w-0 items-center gap-3">
          <button
            id={"#{@id}-toggle"}
            type="button"
            class="group inline-flex h-9 w-9 items-center justify-center rounded-md border border-transparent text-gray-600 transition hover:border-gray-200 hover:bg-gray-50 hover:text-gray-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600 dark:text-gray-300 dark:hover:border-gray-600 dark:hover:bg-gray-700 dark:hover:text-white"
            aria-expanded={to_string(@expanded)}
            aria-controls={"#{@id}-content"}
            phx-click={@toggle_event}
            phx-target={@target}
            phx-value-section_id={@section_id}
            phx-value-expanded={to_string(!@expanded)}
            data-section-toggle
          >
            <span class="sr-only">{toggle_label(@expanded, @title)}</span>
            <i
              class={[
                "fa-solid fa-chevron-down text-sm transition-transform",
                !@expanded && "-rotate-90"
              ]}
              aria-hidden="true"
            />
          </button>

          <h2 class="truncate text-sm font-semibold text-gray-900 dark:text-gray-100">{@title}</h2>
        </div>

        <button
          id={"#{@id}-move"}
          type="button"
          class="inline-flex h-9 w-9 shrink-0 cursor-move items-center justify-center rounded-md border border-transparent text-gray-500 transition hover:border-gray-200 hover:bg-gray-50 hover:text-gray-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600 dark:text-gray-300 dark:hover:border-gray-600 dark:hover:bg-gray-700 dark:hover:text-white"
          aria-label={@move_label}
          title={@move_label}
          draggable="true"
          data-section-handle
        >
          <i class="fa-solid fa-grip-lines text-sm" aria-hidden="true" />
        </button>
      </header>

      <div
        :if={@expanded}
        id={"#{@id}-content"}
        class="p-4"
        data-section-content
      >
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  defp toggle_label(true, title), do: gettext("Collapse %{title} section", title: title)
  defp toggle_label(false, title), do: gettext("Expand %{title} section", title: title)
end
