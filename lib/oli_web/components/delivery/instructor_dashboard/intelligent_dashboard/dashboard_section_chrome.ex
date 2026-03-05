defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.DashboardSectionChrome do
  @moduledoc """
  Reusable chrome wrapper for Intelligent Dashboard section groups.

  Responsibilities:
  - render shared section header/chrome container
  - expose section-level collapse/expand and reorder hooks
  - stay tile-agnostic (no section/tile business rules)

  This module is introduced as a placeholder and will be expanded as
  `MER-5258` / `MER-5259` UX contracts are implemented.
  """

  use OliWeb, :html

  # TODO(MER-XXXX): Finalize shared section chrome contract
  # (header actions, collapse state semantics, accessibility, and optional telemetry hooks).

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :expanded, :boolean, default: true
  slot :inner_block, required: true

  def section(assigns) do
    ~H"""
    <section id={@id} class="mb-4">
      <header class="mb-2">
        <h2 class="text-sm font-semibold">{@title}</h2>
      </header>
      <div :if={@expanded}>
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end
end
