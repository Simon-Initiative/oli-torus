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

  @doc "Returns the raw design-token name (e.g. \"Icon-icon-danger\") for a proficiency/confidence level."
  def color_token("Low"), do: "Icon-icon-danger"
  def color_token("Medium"), do: "Icon-icon-accent-orange"
  def color_token("High"), do: "Text-text-accent-green"
  def color_token(_not_enough_data), do: "Fill-Chip-Gray"

  @doc "Returns the background-color Tailwind class for the color dot matching a proficiency label."
  def dot_class(label), do: "bg-" <> color_token(label)

  @doc "Returns the three cumulative bar-fill classes for the Confidence icon at a given level."
  def confidence_bar_classes(level) when level in ["Low", "Medium", "High"] do
    filled = "fill-" <> color_token(level)
    inactive = "fill-Icon-icon-default"

    case level do
      "High" -> {filled, filled, filled}
      "Medium" -> {filled, filled, inactive}
      "Low" -> {filled, inactive, inactive}
    end
  end

  def confidence_bar_classes(_not_enough_data) do
    inactive = "fill-Icon-icon-default"
    {inactive, inactive, inactive}
  end

  @doc "Returns the full display label (e.g. \"Low Proficiency\") for a chart/filter label."
  def full_label("Low"), do: "Low Proficiency"
  def full_label("Medium"), do: "Medium Proficiency"
  def full_label("High"), do: "High Proficiency"
  def full_label(not_enough_data), do: not_enough_data

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
