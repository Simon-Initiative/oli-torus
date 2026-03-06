defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.TileGroups.ContentSection do
  @moduledoc """
  Content tile-group composition for Intelligent Dashboard.

  Planned group ownership:
  - `ChallengingObjectivesTile`
  - `AssessmentsTile`

  This is a placeholder module for composition boundaries and will be
  implemented incrementally as tile stories land.
  """

  use OliWeb, :html

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.DashboardSectionChrome
  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.AssessmentsTile

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.{
    ChallengingObjectivesTile
  }

  attr :objectives_status, :string, default: "Waiting for scoped data"
  attr :assessments_status, :string, default: "Waiting for scoped data"

  def section(assigns) do
    ~H"""
    <DashboardSectionChrome.section id="learning-dashboard-content-group" title="Content">
      <div class="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <ChallengingObjectivesTile.tile status={@objectives_status} />
        <AssessmentsTile.tile status={@assessments_status} />
      </div>
    </DashboardSectionChrome.section>
    """
  end

  # TODO(MER-XXXX): Compose Content section using DashboardSectionChrome
  # and mount ChallengingObjectives/Assessments tiles with scoped view-model contracts.
end
