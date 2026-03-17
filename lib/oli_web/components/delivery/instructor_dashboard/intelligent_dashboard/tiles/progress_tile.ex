defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.ProgressTile do
  @moduledoc """
  Progress tile placeholder for Intelligent Dashboard (`MER-5251`).

  Target scope:
  - threshold and mode controls
  - chart/pagination state rendering
  - scope-aware progress projection consumption
  """

  use OliWeb, :html

  attr :status, :string, default: "Waiting for scoped data"

  def tile(assigns) do
    ~H"""
    <article
      id="learning-dashboard-progress-placeholder"
      class="h-full rounded-xl border border-Border-border-subtle bg-Surface-surface-primary p-3 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]"
    >
      <div class="mb-3 flex items-start justify-between gap-3">
        <h3 class="text-lg font-semibold leading-6 text-Text-text-high">Progress</h3>
        <span class="rounded-md border border-Border-border-default bg-Background-bg-primary px-2 py-1 text-xs font-semibold leading-4 text-Text-text-low-alpha">
          {@status}
        </span>
      </div>
      <p class="mb-4 text-sm leading-6 text-Text-text-low">
        Completion progress, threshold controls, and schedule-aware chart area.
      </p>
      <div class="space-y-3">
        <div class="h-10 rounded-lg border border-Border-border-default bg-Background-bg-primary">
        </div>
        <div class="grid grid-cols-6 items-end gap-3 rounded-lg border border-Border-border-subtle bg-Background-bg-primary px-4 pb-4 pt-6">
          <div class="h-32 rounded-t-sm bg-Fill-Accent-fill-accent-grey-muted"></div>
          <div class="h-28 rounded-t-sm bg-Fill-Accent-fill-accent-grey-muted"></div>
          <div class="h-24 rounded-t-sm bg-Fill-Accent-fill-accent-grey-muted"></div>
          <div class="h-20 rounded-t-sm bg-Fill-Accent-fill-accent-grey-muted"></div>
          <div class="h-10 rounded-t-sm bg-Fill-Accent-fill-accent-grey-muted"></div>
          <div class="h-4 rounded-t-sm bg-Fill-Accent-fill-accent-grey-muted"></div>
        </div>
      </div>
    </article>
    """
  end

  # TODO(MER-5251): Implement progress tile UI and interactions
  # (threshold/mode controls, chart rendering, and scoped data behavior).
end
