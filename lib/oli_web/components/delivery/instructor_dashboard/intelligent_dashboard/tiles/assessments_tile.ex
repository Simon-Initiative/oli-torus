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
      class="rounded border border-gray-200 bg-white p-4 shadow-sm dark:border-gray-700 dark:bg-gray-800"
    >
      <div class="mb-3 flex items-center justify-between">
        <h3 class="font-semibold text-gray-900 dark:text-gray-100">Assessments</h3>
        <span class="text-xs text-gray-500 dark:text-gray-400">{@status}</span>
      </div>
      <p class="mb-4 text-sm text-gray-600 dark:text-gray-300">
        Assessment distribution, completion, and actions area.
      </p>
      <div class="space-y-2">
        <div class="h-2 rounded bg-gray-100 dark:bg-gray-700"></div>
        <div class="h-2 w-5/6 rounded bg-gray-100 dark:bg-gray-700"></div>
        <div class="h-2 w-2/3 rounded bg-gray-100 dark:bg-gray-700"></div>
      </div>
    </article>
    """
  end

  # TODO(MER-5254): Implement assessments tile
  # (distribution/aggregate states and drill-through UX hooks).
end
