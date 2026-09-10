defmodule OliWeb.Delivery.LearningObjectives.Proficiency do
  @moduledoc """
  Shared presentation for Learning Objectives proficiency labels, chips, and charts.

  Vega requires resolved color values, so the chart palette records the design token
  associated with each light/dark value to keep those mappings explicit.
  """

  use Phoenix.Component

  alias OliWeb.Common.Chip
  alias OliWeb.Icons

  @labels ["Not enough data", "Low", "Medium", "High"]
  @palette [
    %{token: "Fill-Chip-Gray", light: "#CED1D9", dark: "#353740"},
    %{token: "Icon-icon-danger", light: "#CE2C31", dark: "#FF8787"},
    %{token: "Icon-icon-accent-orange", light: "#BF5B13", dark: "#FFB387"},
    %{token: "Text-text-accent-green", light: "#218358", dark: "#39E581"}
  ]

  @doc "Returns proficiency labels in chart order."
  def labels, do: @labels

  @doc "Returns resolved design-token values for the requested Vega chart theme."
  def colors(theme), do: Enum.map(@palette, &Map.fetch!(&1, theme))

  @doc """
  Returns a single solid `fill-*` Tailwind class for a proficiency label, for use on SVG
  shapes (e.g. a filled dot) that need one color rather than the `chip/1` badge's
  background/text pair. Uses the same semantic family as `chip_colors/1` so a dot and a chip
  for the same label always read as the same color.
  """
  @spec dot_fill_class(String.t() | nil, :active | :inactive) :: String.t()
  def dot_fill_class(label, state \\ :active)

  def dot_fill_class("High", :inactive), do: "fill-Graph-dot-high-inactive"
  def dot_fill_class("Medium", :inactive), do: "fill-Graph-dot-medium-inactive"
  def dot_fill_class("Low", :inactive), do: "fill-Graph-dot-low-inactive"
  def dot_fill_class(_, :inactive), do: "fill-Graph-dot-notenoughinfo-inactive"
  def dot_fill_class("High", _state), do: "fill-Graph-dot-high-active"
  def dot_fill_class("Medium", _state), do: "fill-Graph-dot-medium-active"
  def dot_fill_class("Low", _state), do: "fill-Graph-dot-low-active"
  def dot_fill_class(_, _state), do: "fill-Graph-dot-notenoughinfo-active"

  attr :label, :string, required: true

  def chip(assigns) do
    {bg_color, text_color} = chip_colors(assigns.label)

    assigns =
      assign(assigns,
        bg_color: bg_color,
        text_color: text_color,
        show_warning: assigns.label == "Low"
      )

    ~H"""
    <Chip.render
      label={@label}
      bg_color={@bg_color}
      text_color={@text_color}
      label_class="whitespace-nowrap"
    >
      <:icon :if={@show_warning}>
        <span data-role="low-proficiency-warning" aria-hidden="true">
          <Icons.warning_16 />
        </span>
      </:icon>
    </Chip.render>
    """
  end

  defp chip_colors("High"), do: {"bg-Fill-Chip-Green", "text-Text-Chip-Green"}

  defp chip_colors("Medium"),
    do: {"bg-Fill-Accent-fill-accent-orange", "text-Text-Chip-Orange"}

  defp chip_colors("Low"), do: {"bg-Fill-fill-danger", "text-Text-text-danger"}
  defp chip_colors(_), do: {"bg-Fill-Chip-Gray", "text-Text-Chip-Gray"}
end
