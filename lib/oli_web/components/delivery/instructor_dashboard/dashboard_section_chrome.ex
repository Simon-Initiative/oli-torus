defmodule OliWeb.Components.Delivery.InstructorDashboard.DashboardSectionChrome do
  @moduledoc """
  Reusable chrome wrapper for instructor dashboard section groups.

  Responsibilities:
  - render shared section header/chrome container
  - expose section-level collapse/expand and reorder affordances
  - stay tile-agnostic (no section/tile business rules)
  """

  use OliWeb, :html

  alias OliWeb.Icons

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
    assigns =
      assigns
      |> assign(:move_label, assigns.move_label || gettext("Move"))
      |> assign(
        :toggle_icon_class,
        "fill-current transition-transform duration-200" <>
          if(assigns.expanded, do: "", else: " -rotate-90")
      )

    ~H"""
    <section
      id={@id}
      phx-hook="DashboardSectionChrome"
      data-dashboard-section-id={@section_id}
      data-reorder-event={@reorder_event}
      data-section-expanded={to_string(@expanded)}
      class={[
        "overflow-hidden rounded-[12px] border border-Border-border-subtle bg-Background-bg-secondary shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)] transition-[border-color,box-shadow,transform]",
        @class
      ]}
    >
      <header class="flex items-start justify-between gap-4 px-5 py-4">
        <div class="flex min-w-0 items-center gap-1.5">
          <button
            id={"#{@id}-toggle"}
            type="button"
            class="group inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-md text-Icon-icon-default transition hover:bg-Fill-fill-hover hover:text-Icon-icon-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
            aria-expanded={to_string(@expanded)}
            aria-controls={"#{@id}-content"}
            phx-click={@toggle_event}
            phx-target={@target}
            phx-value-section_id={@section_id}
            phx-value-expanded={to_string(!@expanded)}
            data-section-toggle
          >
            <span class="sr-only">{toggle_label(@expanded, @title)}</span>
            <Icons.chevron_down
              width="20"
              height="20"
              class={@toggle_icon_class}
            />
          </button>

          <h2 class="truncate text-2xl font-semibold leading-8 text-Text-text-high">{@title}</h2>
        </div>

        <button
          id={"#{@id}-move"}
          type="button"
          class="inline-flex h-8 w-8 shrink-0 cursor-move items-center justify-center rounded-md text-Icon-icon-active transition hover:bg-Fill-fill-hover hover:text-Icon-icon-active focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
          aria-label={@move_label}
          title={@move_label}
          data-bs-toggle="tooltip"
          data-bs-placement="top"
          draggable="true"
          data-section-handle
        >
          <Icons.drag_handle_dots class="text-current" />
        </button>
      </header>

      <div
        :if={@expanded}
        id={"#{@id}-content"}
        class="px-5 pb-5 pt-4"
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
