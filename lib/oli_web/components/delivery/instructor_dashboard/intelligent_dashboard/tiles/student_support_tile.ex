defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.StudentSupportTile do
  @moduledoc """
  Student Support tile placeholder for Intelligent Dashboard (`MER-5252`).

  Target scope:
  - bucketed support interactions (donut/legend/list sync)
  - filter/search/paging/selection state
  - email workflow handoff hooks
  """

  use OliWeb, :html

  attr :status, :string, default: "Waiting for scoped data"

  def tile(assigns) do
    ~H"""
    <article
      id="learning-dashboard-student-support-placeholder"
      class="h-full rounded-xl border border-Border-border-subtle bg-Surface-surface-primary p-3 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]"
    >
      <div class="mb-3 flex items-start justify-between gap-3">
        <h3 class="text-lg font-semibold leading-6 text-Text-text-high">Student Support</h3>
        <span class="rounded-md border border-Border-border-default bg-Background-bg-primary px-2 py-1 text-xs font-semibold leading-4 text-Text-text-low-alpha">
          {@status}
        </span>
      </div>
      <p class="mb-4 text-sm leading-6 text-Text-text-low">
        Support buckets, filters, student list, and email handoff area.
      </p>
      <div class="grid grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)] gap-3">
        <div class="flex min-h-[220px] items-center justify-center rounded-lg border border-Border-border-subtle bg-Background-bg-primary">
          <div class="h-32 w-32 rounded-full border-[18px] border-Fill-Buttons-fill-chart-purple-muted border-l-Fill-Buttons-fill-chart-blue-muted border-r-Fill-Accent-fill-accent-orange-bold border-b-Fill-Accent-fill-accent-grey">
          </div>
        </div>
        <div class="space-y-2 rounded-lg border border-Border-border-subtle bg-Background-bg-primary p-3">
          <div class="h-9 rounded-md border border-Border-border-default bg-Surface-surface-primary">
          </div>
          <div class="h-9 rounded-md border border-Border-border-default bg-Surface-surface-primary">
          </div>
          <div class="h-9 rounded-md border border-Border-border-default bg-Surface-surface-primary">
          </div>
          <div class="h-9 rounded-md border border-Border-border-default bg-Surface-surface-primary">
          </div>
        </div>
      </div>
    </article>
    """
  end

  # TODO(MER-5252): Implement student-support tile interactions
  # (segment selection, right-panel student list, and action handoffs).
end
