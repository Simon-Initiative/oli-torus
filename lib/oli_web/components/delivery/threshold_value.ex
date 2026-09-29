defmodule OliWeb.Components.Delivery.ThresholdValue do
  @moduledoc """
  Renders a formatted metric with an accessible warning when it is below its threshold.

  Callers retain ownership of threshold policy, value formatting, and color. The warning icon
  inherits the caller's current text color so it stays aligned with each metric's danger state.
  """

  use Phoenix.Component

  alias OliWeb.Icons

  attr :at_risk, :boolean, required: true
  attr :warning_label, :string, required: true

  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1 whitespace-nowrap">
      <span
        :if={@at_risk}
        class="inline-flex shrink-0"
        role="img"
        aria-label={@warning_label}
      >
        <span class="inline-flex" aria-hidden="true">
          <Icons.warning_16 class="size-4 shrink-0 stroke-current" />
        </span>
      </span>
      {render_slot(@inner_block)}
    </span>
    """
  end
end
