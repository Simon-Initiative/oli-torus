defmodule OliWeb.Common.Components do
  @moduledoc """
  Common LiveView Components
  """
  use Phoenix.Component

  def materials_icon_button(assigns) do
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
      <button class={@class} phx-click={@on_click} {@values}><span class="material-icons"><%= @icon %></span></button>
    """
  end
end
