defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.SummaryTile do
  @moduledoc """
  Summary tile placeholder for Intelligent Dashboard.

  Target scope:
  - scoped metric cards
  - recommendation view model rendering
  - feedback/regenerate UI integration points (`MER-5249` / `MER-5250`)
  """

  use OliWeb, :html

  attr :status, :string, default: "Waiting for scoped data"
  attr :recommendation, :map, default: nil

  def tile(assigns) do
    ~H"""
    <article
      id="learning-dashboard-summary-tile"
      class="h-full rounded-xl border border-Border-border-subtle bg-Surface-surface-primary p-3 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]"
    >
      <div class="mb-3 flex items-center justify-between">
        <h3 class="font-semibold text-gray-900 dark:text-gray-100">Summary</h3>
        <div class="flex items-center gap-3">
          <button
            type="button"
            phx-click="summary_recommendation_regenerate"
            class="rounded border border-Border-border-subtle px-2 py-1 text-xs font-medium text-Text-text-high hover:bg-Background-bg-secondary"
          >
            Regenerate
          </button>
          <span class="text-xs text-gray-500 dark:text-gray-400">{@status}</span>
        </div>
      </div>
      <%= if @recommendation do %>
        <div class="rounded-lg border border-Border-border-subtle bg-Background-bg-secondary px-4 py-3">
          <div class="mb-2 text-[11px] font-semibold uppercase tracking-[0.08em] text-Text-text-low">
            AI Recommendation
          </div>
          <p class="text-sm leading-6 text-Text-text-high">{Map.get(@recommendation, :message)}</p>
        </div>
      <% else %>
        <p class="mb-4 text-sm text-gray-600 dark:text-gray-300">
          Scoped metrics and AI recommendation placeholders.
        </p>
        <div class="space-y-2">
          <div class="h-2 rounded bg-gray-100 dark:bg-gray-700"></div>
          <div class="h-2 w-5/6 rounded bg-gray-100 dark:bg-gray-700"></div>
          <div class="h-2 w-2/3 rounded bg-gray-100 dark:bg-gray-700"></div>
        </div>
      <% end %>
    </article>
    """
  end

  # TODO(MER-5249, MER-5250): Implement summary cards and recommendation block
  # using scoped projection data and final interaction contracts.
end
