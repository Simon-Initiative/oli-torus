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
      class="rounded border border-gray-200 bg-white p-4 shadow-sm dark:border-gray-700 dark:bg-gray-800"
    >
      <div class="mb-3 flex items-center justify-between">
        <h3 class="font-semibold text-gray-900 dark:text-gray-100">Student Support</h3>
        <span class="text-xs text-gray-500 dark:text-gray-400">{@status}</span>
      </div>
      <p class="mb-4 text-sm text-gray-600 dark:text-gray-300">
        Support buckets, filters, student list, and email handoff area.
      </p>
      <div class="space-y-2">
        <div class="h-2 rounded bg-gray-100 dark:bg-gray-700"></div>
        <div class="h-2 w-5/6 rounded bg-gray-100 dark:bg-gray-700"></div>
        <div class="h-2 w-2/3 rounded bg-gray-100 dark:bg-gray-700"></div>
      </div>
    </article>
    """
  end

  # TODO(MER-5252): Implement student-support tile interactions
  # (segment selection, right-panel student list, and action handoffs).
end
