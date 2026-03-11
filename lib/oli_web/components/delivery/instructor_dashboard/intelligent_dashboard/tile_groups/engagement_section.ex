defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.TileGroups.EngagementSection do
  @moduledoc """
  Engagement tile-group composition for Intelligent Dashboard.

  Planned group ownership:
  - `ProgressTile`
  - `StudentSupportTile`

  This is a placeholder module for composition boundaries and will be
  implemented incrementally as tile stories land.
  """

  use OliWeb, :html

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.DashboardSectionChrome
  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.ProgressTile

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.StudentSupportTile

  attr :progress_status, :string, default: "Waiting for scoped data"
  attr :student_support_status, :string, default: "Waiting for scoped data"

  def section(assigns) do
    ~H"""
    <DashboardSectionChrome.section id="learning-dashboard-engagement-group" title="Engagement">
      <div class="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <ProgressTile.tile status={@progress_status} />
        <StudentSupportTile.tile status={@student_support_status} />
      </div>
    </DashboardSectionChrome.section>
    """
  end

  # TODO(MER-XXXX): Compose Engagement section using DashboardSectionChrome
  # and mount Progress/StudentSupport tiles with their scoped view-model contracts.
end
