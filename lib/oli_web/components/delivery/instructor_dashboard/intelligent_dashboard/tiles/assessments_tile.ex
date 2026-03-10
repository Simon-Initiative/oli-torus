defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.AssessmentsTile do
  @moduledoc """
  Assessments tile placeholder for Intelligent Dashboard (`MER-5254`).

  Target scope:
  - assessment aggregate/distribution rendering
  - scoped empty/hidden/populated states
  - drill-through action hooks
  """

  use OliWeb, :html

  attr :status, :string, default: "Waiting for scoped data"

  def tile(assigns) do
    ~H"""
    <article
      id="learning-dashboard-assessments-placeholder"
      class="h-full rounded-xl border border-Border-border-subtle bg-Surface-surface-primary p-3 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]"
    >
      <div class="mb-3 flex items-start justify-between gap-3">
        <h3 class="text-lg font-semibold leading-6 text-Text-text-high">Assessments</h3>
        <span class="rounded-md border border-Border-border-default bg-Background-bg-primary px-2 py-1 text-xs font-semibold leading-4 text-Text-text-low-alpha">
          {@status}
        </span>
      </div>
      <p class="mb-4 text-sm leading-6 text-Text-text-low">
        Assessment distribution, completion, and actions area.
      </p>
      <div class="space-y-2 rounded-lg border border-Border-border-subtle bg-Background-bg-primary p-3">
        <div class="h-16 rounded-md border border-Border-border-default bg-Surface-surface-primary">
        </div>
        <div class="h-16 rounded-md border border-Border-border-default bg-Surface-surface-primary">
        </div>
        <div class="h-16 rounded-md border border-Border-border-default bg-Surface-surface-primary">
        </div>
      </div>
    </article>
    """
  end

  # TODO(MER-5254): Implement assessments tile
  # (distribution/aggregate states and drill-through UX hooks).
end
