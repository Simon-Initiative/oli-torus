defmodule OliWeb.Common.Components do
  @moduledoc """
  Common LiveView Components
  """
  use Phoenix.Component

  attr :class, :string, default: nil
  attr :icon, :string, required: true
  attr :on_click, :string, required: true
  attr :values, :list, default: []
  attr :aria_label, :string, required: true

  @doc "Renders an icon-only button with optional accessible labeling."
  def icon_button(assigns) do
    assigns =
      assigns
      |> assign(
        :values,
        case assigns[:values] do
          nil -> []
          values -> values
        end
      )
      |> assign(
        :class,
        case assigns[:class] do
          nil -> "btn icon-button"
          c -> "btn icon-button #{c}"
        end
      )

    ~H"""
    <button class={@class} phx-click={@on_click} aria-label={@aria_label} {@values}>
      <i class={@icon} aria-hidden="true"></i>
    </button>
    """
  end
end
