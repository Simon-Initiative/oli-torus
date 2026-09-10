defmodule OliWeb.Components.Delivery.LearningObjectives.StudentDistributionMatrix do
  @moduledoc """
  Renders the Student Distribution matrix: a two-dimensional plot of enrolled students by
  Learning Proficiency (x-axis) and Activity Completion (y-axis), grouped into three regions
  (Needs Support, Excelling, Limited Activity).

  This is a stateless, pure HEEx/SVG chart -- no charting library, no React, no LiveReact
  registration. It is chosen over a client-rendered chart because this surface does not need
  per-dot hover tooltips beyond a native SVG `<title>`, collapsing of dense same-value dots
  into a grouped marker, or any other client-side chart state. Region and dot selection are
  plain `phx-click`/`phx-keydown` events bubbling to the parent LiveComponent
  (`ExpandedObjectiveView`) via `@myself`.

  The only client-side behavior is the `StudentDistributionMatrixLabels` Phoenix hook, which
  does not render chart state. It only fades a count label when the mouse is over that label
  and the label overlaps at least one student dot. The label layer keeps `pointer-events: none`
  so hover/click hit-testing still reaches the dot or region underneath, preserving native dot
  titles and region selection.

  Every student passed in must already carry `:distribution_group` and
  `:activity_completion`, computed by `Oli.Delivery.Metrics.StudentDistributionGroup.assign/1`.
  This component never recomputes group membership -- it only renders it.

  Colors come from the `Graph-*` design tokens in `assets/tailwind.tokens.js` (light/dark aware);
  adjust them there rather than hardcoding new values in this module.

  Each student's dot is positioned **within its own region's rectangle**, using its
  proficiency/activity value re-normalized to that region's local value range (not a single
  coordinate system spanning the whole plot). This matters because the three regions have a
  visible gap between them (matching Figma): a dot positioned by a single plot-wide mapping
  would drift into that gap, or past a region boundary, for values near 50%.
  """

  use Phoenix.Component

  alias OliWeb.Delivery.LearningObjectives.Proficiency

  @viewbox_width 580
  @viewbox_height 532
  @chart_x 31
  @chart_y 0
  @chart_width 549
  @chart_height 466
  @chart_radius 22
  @grid_x 44
  @grid_y 11
  @grid_width 523
  @grid_height 445
  @region_gap 10
  @region_width (@grid_width - @region_gap) / 2
  @region_height (@grid_height - @region_gap) / 2
  @region_radius 16
  @dot_radius 11.5
  @top_region_dot_top_pad 36.5
  @limited_activity_dot_top_pad 108.0
  @x_tick_y 498
  @x_axis_label_y 530
  @y_axis_label_x 14
  @y_axis_label_y @chart_y + @chart_height / 2

  @regions %{
    needs_support: %{
      x: @grid_x,
      y: @grid_y,
      width: @region_width,
      height: @region_height,
      prof_range: {0.0, 0.5},
      act_range: {0.5, 1.0}
    },
    excelling: %{
      x: @grid_x + @region_width + @region_gap,
      y: @grid_y,
      width: @region_width,
      height: @region_height,
      prof_range: {0.5, 1.0},
      act_range: {0.5, 1.0}
    },
    limited_activity: %{
      x: @grid_x,
      y: @grid_y + @region_height + @region_gap,
      width: @grid_width,
      height: @region_height,
      prof_range: {0.0, 1.0},
      act_range: {0.0, 0.5}
    }
  }

  attr :students, :list, required: true
  attr :selected_group, :atom, default: nil
  attr :myself, :any, required: true
  attr :unique_id, :string, required: true

  def matrix(assigns) do
    counts = group_counts(assigns.students)

    assigns =
      assigns
      |> assign(:viewbox_width, @viewbox_width)
      |> assign(:viewbox_height, @viewbox_height)
      |> assign(:chart_x, @chart_x)
      |> assign(:chart_y, @chart_y)
      |> assign(:chart_width, @chart_width)
      |> assign(:chart_height, @chart_height)
      |> assign(:chart_radius, @chart_radius)
      |> assign(:grid_x, @grid_x)
      |> assign(:grid_y, @grid_y)
      |> assign(:grid_width, @grid_width)
      |> assign(:x_tick_y, @x_tick_y)
      |> assign(:x_axis_label_y, @x_axis_label_y)
      |> assign(:y_axis_label_x, @y_axis_label_x)
      |> assign(:y_axis_label_y, @y_axis_label_y)
      |> assign(:dot_radius, @dot_radius)
      |> assign(:needs_support, @regions.needs_support)
      |> assign(:excelling, @regions.excelling)
      |> assign(:limited_activity, @regions.limited_activity)
      |> assign(:needs_support_count, Map.get(counts, :needs_support, 0))
      |> assign(:excelling_count, Map.get(counts, :excelling, 0))
      |> assign(:limited_activity_count, Map.get(counts, :limited_activity, 0))
      |> assign(:points, Enum.map(assigns.students, &point(&1, assigns.selected_group)))
      |> assign(:x_ticks, x_axis_ticks())

    ~H"""
    <div class="w-full max-w-[580px]">
      <svg
        id={"student-distribution-matrix-#{@unique_id}"}
        phx-hook="StudentDistributionMatrixLabels"
        viewBox={"0 0 #{@viewbox_width} #{@viewbox_height}"}
        aria-label="Student distribution matrix"
        aria-describedby={"student-distribution-matrix-desc-#{@unique_id}"}
        overflow="visible"
        class="h-auto w-full overflow-visible"
      >
        <!--
          Deliberately no role="img" here: this SVG contains real interactive
          role="button" regions below, and role="img" would force every descendant
          into the accessibility tree as presentational, hiding those buttons (and
          their aria-pressed state) from screen readers.
        -->
        <desc id={"student-distribution-matrix-desc-#{@unique_id}"}>
          Learning proficiency on the horizontal axis, activity completion on the vertical axis.
        </desc>

        <rect
          x={@chart_x}
          y={@chart_y}
          width={@chart_width}
          height={@chart_height}
          rx={@chart_radius}
          class="fill-Background-bg-secondary"
        />

        <.region
          rect={@needs_support}
          group={:needs_support}
          label="Needs Support"
          count={@needs_support_count}
          selected={@selected_group == :needs_support}
          myself={@myself}
          fill_class="fill-Fill-fill-danger"
          border_class="stroke-Border-border-danger"
        />
        <.region
          rect={@excelling}
          group={:excelling}
          label="Excelling"
          count={@excelling_count}
          selected={@selected_group == :excelling}
          myself={@myself}
          fill_class="fill-Graph-region-excelling"
          border_class="stroke-Graph-dot-high-active"
        />
        <.region
          rect={@limited_activity}
          group={:limited_activity}
          label="Limited Activity"
          count={@limited_activity_count}
          selected={@selected_group == :limited_activity}
          myself={@myself}
          fill_class="fill-Graph-region-limited-activity"
          border_class="stroke-Graph-dot-notenoughinfo-active"
        />

        <g data-student-points="true">
          <circle
            :for={point <- @points}
            cx={point.cx}
            cy={point.cy}
            r={@dot_radius}
            stroke-width={point.stroke_width}
            class={[point.fill_class, point.stroke_class, "cursor-pointer"]}
            phx-click="select_student_group"
            phx-value-group={point.group_value}
            phx-target={@myself}
          >
            <title>{point.label}</title>
          </circle>
        </g>

        <.region_badge
          rect={@needs_support}
          label="Needs Support"
          count={@needs_support_count}
        />
        <.region_badge
          rect={@excelling}
          label="Excelling"
          count={@excelling_count}
        />
        <.region_badge
          rect={@limited_activity}
          label="Limited Activity"
          count={@limited_activity_count}
        />

        <g data-x-axis="true">
          <text
            :for={tick <- @x_ticks}
            x={tick.x}
            y={@x_tick_y}
            text-anchor={tick.anchor}
            class="fill-Text-text-low-alpha font-open-sans text-[14px] font-semibold leading-4"
          >
            {tick.label}
          </text>
          <text
            x={@grid_x + @grid_width / 2}
            y={@x_axis_label_y}
            text-anchor="middle"
            class="fill-Text-text-low-alpha font-open-sans text-[12px] font-bold uppercase leading-3"
          >
            Learning Proficiency
          </text>
        </g>

        <text
          transform={"rotate(-90, #{@y_axis_label_x}, #{@y_axis_label_y})"}
          x={@y_axis_label_x}
          y={@y_axis_label_y}
          text-anchor="middle"
          class="fill-Text-text-low-alpha font-open-sans text-[12px] font-bold uppercase leading-3"
        >
          Activity Completion
        </text>
      </svg>
    </div>
    """
  end

  attr :rect, :map, required: true
  attr :group, :atom, required: true
  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :selected, :boolean, required: true
  attr :myself, :any, required: true
  attr :fill_class, :string, required: true
  attr :border_class, :string, required: true

  defp region(assigns) do
    %{x: x, y: y, width: width, height: height} = assigns.rect

    assigns =
      assigns
      |> assign(:x, x)
      |> assign(:y, y)
      |> assign(:width, width)
      |> assign(:height, height)
      |> assign(:region_radius, @region_radius)
      |> assign(:group_value, to_string(assigns.group))

    ~H"""
    <g
      tabindex="0"
      role="button"
      aria-pressed={to_string(@selected)}
      aria-label={region_aria_label(@label, @count, @selected)}
      phx-click="select_student_group"
      phx-keydown="select_student_group"
      phx-value-group={@group_value}
      phx-target={@myself}
      class="cursor-pointer outline-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
    >
      <rect x={@x} y={@y} width={@width} height={@height} rx={@region_radius} class={@fill_class} />
      <rect
        :if={@selected}
        x={@x + 1}
        y={@y + 1}
        width={@width - 2}
        height={@height - 2}
        rx={@region_radius - 1}
        fill="none"
        class={@border_class}
        stroke-width="2"
      />
    </g>
    """
  end

  attr :rect, :map, required: true
  attr :label, :string, required: true
  attr :count, :integer, required: true

  defp region_badge(assigns) do
    %{x: x, y: y} = assigns.rect

    # Single white pill containing both the dark count chip and the label text, matching
    # the Figma reference exactly: one continuous white background, not two abutting shapes.
    chip_size = 33
    pill_pad_x = 8
    pill_pad_right = 17
    chip_text_gap = 9
    label_text_width = label_text_width(assigns.label)
    pill_x = x + 16
    pill_y = y + 12
    pill_height = chip_size + 18
    pill_width = pill_pad_x + chip_size + chip_text_gap + label_text_width + pill_pad_right
    chip_x = pill_x + pill_pad_x
    chip_y = pill_y + (pill_height - chip_size) / 2
    text_x = chip_x + chip_size + chip_text_gap

    assigns =
      assigns
      |> assign(:pill_x, pill_x)
      |> assign(:pill_y, pill_y)
      |> assign(:pill_width, pill_width)
      |> assign(:pill_height, pill_height)
      |> assign(:chip_x, chip_x)
      |> assign(:chip_y, chip_y)
      |> assign(:chip_size, chip_size)
      |> assign(:text_x, text_x)

    ~H"""
    <g
      data-count-badge="true"
      class="pointer-events-none transition-opacity duration-150"
    >
      <rect
        x={@pill_x}
        y={@pill_y}
        width={@pill_width}
        height={@pill_height}
        rx="6"
        class="fill-Icon-icon-white"
      />
      <rect
        x={@chip_x}
        y={@chip_y}
        width={@chip_size}
        height={@chip_size}
        rx="6"
        class="fill-Black-Alpha-000"
      />
      <text
        x={@chip_x + @chip_size / 2}
        y={@chip_y + @chip_size / 2 + 5.5}
        text-anchor="middle"
        class="fill-Text-text-white font-open-sans text-[16px] font-bold leading-4"
      >
        {@count}
      </text>
      <text
        x={@text_x}
        y={@pill_y + @pill_height / 2 + 5.5}
        text-anchor="start"
        class="fill-Text-text-charcoal font-open-sans text-[16px] font-bold leading-4"
      >
        {@label}
      </text>
    </g>
    """
  end

  defp point(student, selected_group) do
    group = Map.get(student, :distribution_group)
    region = Map.fetch!(@regions, group)
    proficiency = clamp(Map.get(student, :proficiency) || 0.0)
    activity_completion = clamp(Map.get(student, :activity_completion) || 0.0)

    {prof_min, prof_max} = region.prof_range
    {act_min, act_max} = region.act_range

    local_prof = normalize(proficiency, prof_min, prof_max)
    local_act = normalize(activity_completion, act_min, act_max)

    inner_x0 = region.x + @dot_radius
    inner_x1 = region.x + region.width - @dot_radius
    inner_y0 = region.y + dot_top_pad(group)
    inner_y1 = region.y + region.height - @dot_radius
    dot_state = dot_state(group, selected_group)

    %{
      cx: inner_x0 + local_prof * (inner_x1 - inner_x0),
      cy: inner_y1 - local_act * (inner_y1 - inner_y0),
      label: Map.get(student, :full_name) || "Student",
      group_value: to_string(group),
      fill_class: Proficiency.dot_fill_class(Map.get(student, :proficiency_range), dot_state),
      stroke_class: dot_stroke_class(dot_state),
      stroke_width: dot_stroke_width(dot_state)
    }
  end

  defp dot_state(_group, nil), do: :inactive
  defp dot_state(group, group), do: :active
  defp dot_state(_group, _selected_group), do: :inactive

  defp dot_stroke_class(:active), do: "stroke-white"
  defp dot_stroke_class(:inactive), do: nil

  defp dot_stroke_width(:active), do: "1.5"
  defp dot_stroke_width(:inactive), do: "0"

  defp dot_top_pad(:limited_activity), do: @limited_activity_dot_top_pad
  defp dot_top_pad(_group), do: @top_region_dot_top_pad

  # Re-normalizes `value` (already known to fall within [range_min, range_max], since the
  # caller looked it up via the student's own `distribution_group`) to 0.0..1.0 local to that
  # region. Degenerate ranges (e.g. Limited Activity's activity range collapsing if min==max)
  # fall back to the region's midpoint rather than dividing by zero.
  defp normalize(_value, min, max) when min == max, do: 0.5

  defp normalize(value, min, max) do
    ((value - min) / (max - min)) |> max(0.0) |> min(1.0)
  end

  defp clamp(value) when is_number(value), do: value |> max(0.0) |> min(1.0)
  defp clamp(_value), do: 0.0

  defp group_counts(students) do
    Enum.frequencies_by(students, &Map.get(&1, :distribution_group))
  end

  defp region_aria_label(label, count, selected) do
    student_word = if count == 1, do: "student", else: "students"
    selected_suffix = if selected, do: ", selected", else: ""
    "#{label}, #{count} #{student_word}#{selected_suffix}"
  end

  defp x_axis_ticks do
    [
      %{pct: 0.0, label: "0", anchor: "start"},
      %{pct: 0.25, label: "25%", anchor: "middle"},
      %{pct: 0.5, label: "50%", anchor: "middle"},
      %{pct: 0.75, label: "75%", anchor: "middle"},
      %{pct: 1.0, label: "100%", anchor: "end"}
    ]
    |> Enum.map(fn tick -> Map.put(tick, :x, @grid_x + tick.pct * @grid_width) end)
  end

  # Figma uses Open Sans Bold 16px labels. There is no server-side text measurement here,
  # so keep a tuned average width for the three static labels rendered by this component.
  defp label_text_width(label), do: String.length(label) * 8.95
end
