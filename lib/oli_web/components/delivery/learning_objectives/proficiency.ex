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

  # Tailwind's content scanner requires each full class name to appear as a literal
  # string somewhere in the scanned source — even for classes registered by our token
  # plugin via addComponents. Building the class from a prefix plus a separately-held
  # token name (e.g. "bg-" <> color_token(label)) hides the complete name from that
  # scan, and Tailwind then drops the light-mode rule for that class (its dark-mode
  # rule survives independently). Keep each clause's full class name literal here.
  @doc "Returns the background-color Tailwind class for the color dot matching a proficiency label."
  def dot_class("Low"), do: "bg-Icon-icon-danger"
  def dot_class("Medium"), do: "bg-Icon-icon-accent-orange"
  def dot_class("High"), do: "bg-Text-text-accent-green"
  def dot_class(_not_enough_data), do: "bg-Fill-Chip-Gray"

  @doc "Returns the full display label (e.g. \"Low Proficiency\") for a chart/filter label."
  def full_label("Low"), do: "Low Proficiency"
  def full_label("Medium"), do: "Medium Proficiency"
  def full_label("High"), do: "High Proficiency"
  def full_label(not_enough_data), do: not_enough_data

  attr :id, :string,
    required: true,
    doc: "Unique id for the tooltip, referenced by the trigger's aria-describedby."

  attr :distribution, :map,
    required: true,
    doc: "Raw counts per label, e.g. %{\"Low\" => 2, \"High\" => 1}."

  slot :inner_block, required: true, doc: "The chart/bar content the tooltip is attached to."

  @doc """
  Wraps chart content (the inner_block) with the keyboard-and-hover-accessible
  Proficiency Distribution tooltip. Shared by the parent objectives table and the
  expanded sub-objectives table so both render byte-identical tooltips.
  """
  def distribution_chart_with_tooltip(assigns) do
    ~H"""
    <div
      class="relative flex rounded focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 dark:focus-visible:ring-blue-600 focus-visible:ring-offset-2 [&:hover>.proficiency-dist-tooltip]:flex [&:focus-within>.proficiency-dist-tooltip]:flex"
      tabindex="0"
      aria-describedby={@id}
    >
      {render_slot(@inner_block)}
      <.distribution_tooltip id={@id} distribution={@distribution} />
    </div>
    """
  end

  attr :id, :string, required: true
  attr :distribution, :map, required: true

  defp distribution_tooltip(assigns) do
    assigns =
      assigns
      |> assign(:percentages, distribution_percentages(assigns.distribution))
      |> assign(:labels, @labels)

    ~H"""
    <div
      id={@id}
      role="tooltip"
      class="proficiency-dist-tooltip absolute top-[calc(100%+5px)] left-1/2 -translate-x-1/2 p-0 m-0 w-80 rounded-md border border-Border-border-default bg-Surface-surface-background px-4 py-2 text-left text-sm font-normal leading-normal text-Text-text-high shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] hidden flex-col z-50"
    >
      <%= for label <- @labels, value = Map.get(@percentages, label, 0) do %>
        <div class="flex h-6 w-full items-center gap-1.5 text-left">
          <span
            class={"inline-block h-3 w-3 shrink-0 rounded-full " <> dot_class(label)}
            aria-hidden="true"
          >
          </span>
          <b>{full_label(label)}:</b> {value}%
        </div>
      <% end %>
    </div>
    """
  end

  defp distribution_percentages(data) do
    total = data |> Map.values() |> Enum.sum()

    percentage_for = fn label ->
      if total == 0, do: 0, else: round(Map.get(data, label, 0) / total * 100)
    end

    Map.new(@labels, fn label -> {label, percentage_for.(label)} end)
  end

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
