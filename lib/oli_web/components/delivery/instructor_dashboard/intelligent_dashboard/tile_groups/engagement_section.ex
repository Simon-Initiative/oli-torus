defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.TileGroups.EngagementSection do
  @moduledoc """
  Engagement tile-group composition for Intelligent Dashboard.

  This module wraps the Engagement tiles with the shared
  `DashboardSectionChrome` and derives the section layout from the
  number of visible tiles.

  Group ownership:
  - `ProgressTile`
  - `StudentSupportTile`
  """

  use OliWeb, :html

  alias OliWeb.Components.Delivery.InstructorDashboard.DashboardSectionChrome
  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.ProgressTile

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.StudentSupportTile

  attr :expanded, :boolean, default: true
  attr :target, :any, default: nil
  attr :toggle_event, :string, default: "dashboard_section_toggled"
  attr :reorder_event, :string, default: "dashboard_sections_reordered"
  attr :progress_status, :string, default: "Waiting for scoped data"
  attr :student_support_status, :string, default: "Waiting for scoped data"
  attr :show_progress_tile, :boolean, default: true
  attr :show_student_support_tile, :boolean, default: true

  def section(assigns) do
    assigns = assign(assigns, :tile_count, visible_tile_count(assigns))

    ~H"""
    <DashboardSectionChrome.section
      id="learning-dashboard-engagement-group"
      section_id="engagement"
      title="Engagement"
      expanded={@expanded}
      target={@target}
      toggle_event={@toggle_event}
      reorder_event={@reorder_event}
    >
      <div
        class={["grid grid-cols-1 gap-4", @tile_count > 1 && "xl:grid-cols-2"]}
        data-section-layout={if @tile_count == 1, do: "single", else: "multi"}
      >
        <ProgressTile.tile :if={@show_progress_tile} status={@progress_status} />
        <StudentSupportTile.tile
          :if={@show_student_support_tile}
          status={@student_support_status}
        />
      </div>
    </DashboardSectionChrome.section>
    """
  end

  defp visible_tile_count(assigns) do
    Enum.count([assigns.show_progress_tile, assigns.show_student_support_tile], & &1)
  end
end
