defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.StudentSupportParametersModal do
  @moduledoc """
  Student Support parameter customization modal.
  """

  use OliWeb, :html

  alias Oli.InstructorDashboard.StudentSupportParameterSettings
  alias Oli.InstructorDashboard.StudentSupportParameters
  alias OliWeb.Components.DesignTokens.Primitives.Button
  alias OliWeb.Icons
  alias OliWeb.Components.Modal
  alias Phoenix.LiveView.JS

  @inactivity_options [7, 14, 30, 90]
  @matrix_handle_radius 5.25
  @matrix_plot_left 34
  @matrix_plot_top 20
  @matrix_plot_size 220
  @matrix_viewbox_size 280

  attr :show, :boolean, default: false
  attr :draft, :map, default: nil
  attr :changeset, :map, default: nil
  attr :student_points, :list, default: []
  attr :error, :atom, default: nil
  attr :modal_dom_id, :string, default: "student_support_parameters_modal"

  def modal(assigns) do
    draft = normalize_draft(assigns.draft)

    changeset =
      assigns[:changeset] ||
        StudentSupportParameterSettings.changeset(%StudentSupportParameterSettings{}, draft)

    assigns =
      assigns
      |> assign(:draft, draft)
      |> assign(:changeset, changeset)
      |> assign(:show_validation_hint, not changeset.valid? and changeset.errors != [])
      |> assign(:inactivity_options, @inactivity_options)
      |> assign(:student_points, matrix_student_points(assigns.student_points || [], draft))
      |> assign(:threshold_groups, threshold_groups())

    ~H"""
    <Modal.modal
      id={@modal_dom_id}
      wrapper_class="w-full p-0"
      class="ml-auto mr-auto max-h-[calc(100vh-2rem)] max-w-[943px] rounded-[16px] border border-Border-border-default bg-Surface-surface-background shadow-[0_2px_10px_rgba(0,50,99,0.10)]"
      container_class="relative flex max-h-[calc(100vh-2rem)] flex-col overflow-hidden bg-Surface-surface-background transition"
      header_class="flex items-start justify-between bg-Surface-surface-background px-6 pt-6 pb-4 md:px-10 md:pt-8 lg:px-16 lg:pt-16"
      body_class="flex-1 overflow-y-auto bg-Surface-surface-background px-6 pt-0 pb-0 md:px-10 lg:px-16"
      show={@show}
      show_close={false}
      on_cancel={JS.push("student_support_parameters_cancelled")}
    >
      <:title>
        <span class="text-[24px] font-bold leading-8 text-Text-text-high">
          Customize Student Support Parameters
        </span>
      </:title>
      <:header_actions>
        <div class="-mr-3 -mt-3 md:-mr-4 md:-mt-4 lg:-mr-5 lg:-mt-5">
          <Button.button
            variant={:close}
            aria-label="Close customize student support parameters modal"
            phx-click={
              Modal.hide_modal(
                JS.push("student_support_parameters_cancelled"),
                @modal_dom_id
              )
            }
          />
        </div>
      </:header_actions>

      <form
        id="student-support-parameters-form"
        phx-submit="student_support_parameters_saved"
        autocomplete="off"
        class="space-y-[17px]"
      >
        <section class="space-y-4">
          <div class="flex items-center gap-1">
            <span class="h-[9px] w-[9px] rounded-full bg-Fill-Chart-fill-chart-red-active"></span>
            <h4 class="text-[18px] font-bold leading-6 text-Text-text-high">
              Inactive
            </h4>
          </div>
          <p class="max-w-[378px] text-sm leading-4 text-Text-text-high">
            Students who have no activity in the selected time range.
          </p>

          <div class="space-y-[6px]">
            <label
              for="student-support-parameters-inactivity-days"
              class="block text-sm font-semibold leading-4 text-Text-text-high"
            >
              Last visit
            </label>
            <select
              id="student-support-parameters-inactivity-days"
              name="inactivity_days"
              value={value(@draft, :inactivity_days)}
              class="h-8 w-[192px] rounded-md border border-Specially-Tokens-Border-border-input bg-Specially-Tokens-Fill-fill-input px-2 text-sm font-medium leading-4 text-Text-text-high focus:outline-none focus:ring-2 focus:ring-Fill-Buttons-fill-primary"
            >
              <option
                :for={days <- @inactivity_options}
                value={days}
                selected={normalize_value(value(@draft, :inactivity_days)) == days}
              >
                {"> #{days} days"}
              </option>
            </select>
          </div>
          <.field_error changeset={@changeset} field={:inactivity_days} />
        </section>

        <section class="space-y-6">
          <div class="space-y-3">
            <div class="space-y-1">
              <h4 class="text-[18px] font-bold leading-6 text-Text-text-high">
                Group Ranges
              </h4>
              <p class="max-w-[779px] text-sm leading-4 text-Text-text-high">
                Students are grouped using <span class="font-bold">both progress and proficiency</span>.
                <span class="font-bold">Progress</span>
                is how much of the selected content the student has completed.
                <span class="font-bold">Proficiency</span>
                is a measure of how accurately the student answers questions tied to learning objectives on their first attempt.
              </p>
            </div>
          </div>

          <div class="grid items-start gap-[35px] lg:grid-cols-[305px_minmax(360px,1fr)]">
            <div class="space-y-[18px]">
              <.threshold_group
                :for={group <- @threshold_groups}
                group={group}
                draft={@draft}
                changeset={@changeset}
              />
            </div>

            <.matrix draft={@draft} student_points={@student_points} />
          </div>
        </section>

        <div
          :if={@error}
          class="rounded-md border border-Fill-Chart-fill-chart-red-active bg-Background-bg-primary p-3 text-sm leading-5 text-Text-text-high"
          role="alert"
        >
          {error_message(@error)}
        </div>

        <p :if={@show_validation_hint} class="text-sm leading-5 text-Text-text-low" role="alert">
          Adjust the thresholds before saving. The shared high-progress boundary must stay above the low-progress boundary, and proficiency boundaries cannot overlap.
        </p>
      </form>

      <:custom_footer>
        <div class="relative z-10 flex items-center justify-end gap-6 bg-Surface-surface-background px-6 py-5 md:px-10 lg:px-16 lg:py-6">
          <Button.button
            variant={:secondary}
            size={:sm}
            phx-click={
              Modal.hide_modal(
                JS.push("student_support_parameters_cancelled"),
                @modal_dom_id
              )
            }
          >
            Cancel
          </Button.button>
          <Button.button
            variant={:primary}
            size={:sm}
            type="submit"
            form="student-support-parameters-form"
          >
            Save
          </Button.button>
        </div>
      </:custom_footer>
    </Modal.modal>
    """
  end

  attr :group, :map, required: true
  attr :draft, :map, required: true
  attr :changeset, :map, required: true

  defp threshold_group(assigns) do
    ~H"""
    <fieldset class="space-y-[6px]">
      <legend class="flex items-center gap-1 text-sm font-medium leading-4 text-Text-text-high">
        <span class={["h-[9px] w-[9px] rounded-full", @group.dot_class]}></span>
        {@group.title}
      </legend>
      <p class="max-w-[247px] text-sm leading-4 text-Text-text-high">{@group.description}</p>

      <div :if={@group.rows != []} class="space-y-2">
        <div
          :for={row <- @group.rows}
          class="grid grid-cols-[79px_minmax(0,1fr)] items-center gap-1"
        >
          <span class="text-sm font-medium leading-4 text-Text-text-low-alpha">
            {row.label}:
          </span>
          <div class="flex flex-wrap items-center gap-2">
            <%= for {control, index} <- Enum.with_index(row.controls) do %>
              <.threshold_input
                field={control.field}
                comparator={control.comparator}
                value={value(@draft, control.field)}
                label={field_label(control.field)}
                changeset={@changeset}
                accent_class={@group.text_class}
              />
              <span
                :if={@group.title == "Struggling" and row.label == "Progress" and index == 0}
                class="text-sm font-medium leading-4 text-Text-text-low-alpha"
              >
                OR
              </span>
            <% end %>
          </div>
        </div>
      </div>
    </fieldset>
    """
  end

  attr :field, :atom, required: true
  attr :comparator, :string, required: true
  attr :value, :any, required: true
  attr :label, :string, required: true
  attr :changeset, :map, required: true
  attr :accent_class, :string, required: true

  defp threshold_input(assigns) do
    ~H"""
    <div class="space-y-1">
      <div class="grid h-[35px] w-[83px] grid-cols-[1fr_12px] items-stretch overflow-hidden rounded-md border border-Border-border-default bg-transparent">
        <label for={"student-support-parameters-#{@field}"} class="sr-only">{@label}</label>
        <div class="flex min-w-0 items-center gap-[2px] px-[9px]">
          <span class={["text-sm font-medium leading-4", @accent_class]}>
            {@comparator}
          </span>
          <input
            id={"student-support-parameters-#{@field}"}
            type="text"
            name={@field}
            value={@value}
            autocomplete="off"
            inputmode="numeric"
            pattern="[0-9]*"
            style="background: transparent !important; -webkit-box-shadow: 0 0 0 1000px transparent inset;"
            class={[
              "w-6 appearance-none border-0 bg-transparent p-0 pr-0 text-right text-sm font-medium leading-4 shadow-none focus:outline-none focus:ring-0",
              @accent_class
            ]}
            aria-invalid={field_invalid?(@changeset, @field)}
            aria-describedby={input_description_ids(@changeset, @field)}
          />
          <span
            id={"student-support-parameters-#{@field}-suffix"}
            class={["-ml-[1px] text-sm font-medium leading-4", @accent_class]}
          >
            %
          </span>
        </div>
        <div class="flex w-3 shrink-0 flex-col items-center justify-center gap-[3px] pr-[6px]">
          <button
            type="button"
            tabindex="-1"
            class="flex h-3 w-3 items-center justify-center rounded-[3px] border border-Specially-Tokens-Border-border-input bg-Background-bg-primary text-Text-text-low-alpha"
            aria-label={"Increase #{@label}"}
            data-step-field={@field}
            data-step-direction="1"
          >
            <Icons.chevron_up class="h-3 w-3 stroke-current" />
          </button>
          <button
            type="button"
            tabindex="-1"
            class="flex h-3 w-3 items-center justify-center rounded-[3px] border border-Specially-Tokens-Border-border-input bg-Background-bg-primary text-Text-text-low-alpha"
            aria-label={"Decrease #{@label}"}
            data-step-field={@field}
            data-step-direction="-1"
          >
            <Icons.chevron_down class="h-3 w-3 stroke-current" />
          </button>
        </div>
      </div>
      <.field_error changeset={@changeset} field={@field} />
    </div>
    """
  end

  attr :changeset, :map, required: true
  attr :field, :atom, required: true

  defp field_error(assigns) do
    ~H"""
    <p
      :if={field_error(@changeset, @field)}
      id={"student-support-parameters-#{@field}-error"}
      class="text-xs leading-4 text-Fill-Chart-fill-chart-red-active"
    >
      {field_error(@changeset, @field)}
    </p>
    """
  end

  attr :draft, :map, required: true
  attr :student_points, :list, required: true

  defp matrix(assigns) do
    geometry = matrix_geometry(assigns.draft)

    assigns =
      assigns
      |> assign(:matrix_plot_left, @matrix_plot_left)
      |> assign(:matrix_plot_top, @matrix_plot_top)
      |> assign(:matrix_plot_size, @matrix_plot_size)
      |> assign(:matrix_viewbox_size, @matrix_viewbox_size)
      |> assign(:low_x, geometry.low_x)
      |> assign(:shared_progress_x, geometry.shared_progress_x)
      |> assign(:struggling_y, geometry.struggling_y)
      |> assign(:excelling_y, geometry.excelling_y)
      |> assign(:struggling_left_width, geometry.struggling_left_width)
      |> assign(:struggling_right_width, geometry.struggling_right_width)
      |> assign(:struggling_height, geometry.struggling_height)
      |> assign(:excelling_width, geometry.excelling_width)
      |> assign(:excelling_height, geometry.excelling_height)
      |> assign(:vertical_handle_top_y, geometry.vertical_handle_top_y)
      |> assign(:vertical_handle_bottom_y, geometry.vertical_handle_bottom_y)
      |> assign(
        :struggling_proficiency_left_handle_x,
        geometry.struggling_proficiency_left_handle_x
      )
      |> assign(
        :struggling_proficiency_right_handle_x,
        geometry.struggling_proficiency_right_handle_x
      )
      |> assign(:horizontal_handle_left_x, geometry.horizontal_handle_left_x)
      |> assign(:horizontal_handle_right_x, geometry.horizontal_handle_right_x)

    ~H"""
    <div class="relative space-y-2" style="top: -41px;">
      <div class="relative mx-auto max-w-[470px]" style="top: 28px;">
        <p class="text-center text-sm leading-4 text-Text-text-high">
          Adjust by dragging the boundaries or using the arrows.<br /> Each dot represents
          <span class="font-bold">one</span>
          student.
        </p>
      </div>
      <div
        id="student-support-parameters-matrix"
        phx-hook="StudentSupportParametersMatrix"
        class="group mx-auto max-w-[470px]"
      >
        <svg
          viewBox={"0 0 #{@matrix_viewbox_size} #{@matrix_viewbox_size}"}
          role="img"
          aria-labelledby="student-support-parameters-matrix-title student-support-parameters-matrix-description"
          class="h-auto w-full"
        >
          <title id="student-support-parameters-matrix-title">Student support threshold matrix</title>
          <desc id="student-support-parameters-matrix-description">
            Progress thresholds move horizontally, and proficiency thresholds move vertically.
          </desc>
          <rect
            x={@matrix_plot_left}
            y={@matrix_plot_top}
            width={@matrix_plot_size}
            height={@matrix_plot_size}
            rx="2"
            class="fill-[#154A53] dark:fill-[#0F2B30] stroke-[#3B3740] dark:stroke-[#3B3740]"
          />
          <rect
            data-region="on-track"
            x={@matrix_plot_left}
            y={@matrix_plot_top}
            width={@matrix_plot_size}
            height={@matrix_plot_size}
            rx="2"
            class="fill-[#1A5861] dark:fill-[#103137]"
          />
          <line
            x1="78"
            y1={@matrix_plot_top}
            x2="78"
            y2="240"
            class="stroke-[#3B3740] stroke-[0.45] opacity-55 dark:stroke-[#3B3740]"
          />
          <line
            x1="122"
            y1={@matrix_plot_top}
            x2="122"
            y2="240"
            class="stroke-[#3B3740] stroke-[0.45] opacity-55 dark:stroke-[#3B3740]"
          />
          <line
            x1="166"
            y1={@matrix_plot_top}
            x2="166"
            y2="240"
            class="stroke-[#3B3740] stroke-[0.45] opacity-55 dark:stroke-[#3B3740]"
          />
          <line
            x1="210"
            y1={@matrix_plot_top}
            x2="210"
            y2="240"
            class="stroke-[#3B3740] stroke-[0.45] opacity-55 dark:stroke-[#3B3740]"
          />
          <line
            x1={@matrix_plot_left}
            y1="64"
            x2="254"
            y2="64"
            class="stroke-[#3B3740] stroke-[0.45] opacity-55 dark:stroke-[#3B3740]"
          />
          <line
            x1={@matrix_plot_left}
            y1="108"
            x2="254"
            y2="108"
            class="stroke-[#3B3740] stroke-[0.45] opacity-55 dark:stroke-[#3B3740]"
          />
          <line
            x1={@matrix_plot_left}
            y1="152"
            x2="254"
            y2="152"
            class="stroke-[#3B3740] stroke-[0.45] opacity-55 dark:stroke-[#3B3740]"
          />
          <line
            x1={@matrix_plot_left}
            y1="196"
            x2="254"
            y2="196"
            class="stroke-[#3B3740] stroke-[0.45] opacity-55 dark:stroke-[#3B3740]"
          />
          <rect
            data-region="struggling-left"
            x="34"
            y={@struggling_y}
            width={@struggling_left_width}
            height={@struggling_height}
            class="fill-[#FF9C54] opacity-[0.30] dark:fill-[#FF9C54]"
          />
          <rect
            data-region="struggling-right"
            x={@shared_progress_x}
            y={@struggling_y}
            width={@struggling_right_width}
            height={@struggling_height}
            class="fill-[#FF9C54] opacity-[0.30] dark:fill-[#FF9C54]"
          />
          <rect
            data-region="excelling"
            x={@shared_progress_x}
            y="20"
            width={@excelling_width}
            height={@excelling_height}
            class="fill-Fill-Chart-fill-chart-purple-muted dark:fill-Fill-Chart-fill-chart-purple-active opacity-[0.30]"
          />
          <g data-student-points="true" class="opacity-90">
            <circle
              :for={point <- @student_points}
              data-student-point="true"
              data-progress={point.progress_pct}
              data-proficiency={point.proficiency_pct}
              cx={point.x}
              cy={point.y}
              r="3.5"
              class={point.class}
            >
              <title>{point.label}</title>
            </circle>
          </g>
          <text
            data-region-label="on-track"
            data-full-label="On track"
            x="44"
            y="30"
            text-anchor="start"
            dominant-baseline="hanging"
            class="fill-Text-text-white text-[9px] font-bold"
          >
            On track
          </text>
          <text
            data-region-label="excelling"
            data-full-label="Excelling"
            x={@shared_progress_x + 10}
            y="30"
            text-anchor="start"
            dominant-baseline="hanging"
            class="fill-Text-text-white text-[9px] font-bold"
          >
            Excelling
          </text>
          <text
            data-region-label="struggling"
            data-full-label="Struggling"
            x="44"
            y={@struggling_y + 10}
            text-anchor="start"
            dominant-baseline="hanging"
            class="fill-Text-text-white text-[9px] font-bold"
          >
            Struggling
          </text>
          <line
            x1={@matrix_plot_left}
            y1="240"
            x2="254"
            y2="240"
            class="stroke-[#3B3740] dark:stroke-[#3B3740]"
          />
          <line
            x1={@matrix_plot_left}
            y1={@matrix_plot_top}
            x2={@matrix_plot_left}
            y2="240"
            class="stroke-[#3B3740] dark:stroke-[#3B3740]"
          />
          <line
            data-threshold-line="struggling_progress_low_lt"
            x1={@low_x}
            y1="20"
            x2={@low_x}
            y2="240"
            class="stroke-white stroke-[2.3]"
          />
          <line
            data-threshold-line="shared_progress_high"
            x1={@shared_progress_x}
            y1="20"
            x2={@shared_progress_x}
            y2="240"
            class="stroke-white stroke-[2.3]"
          />
          <line
            data-threshold-line="struggling_proficiency_lte"
            x1="34"
            y1={@struggling_y}
            x2="254"
            y2={@struggling_y}
            class="stroke-white stroke-[2.3]"
          />
          <line
            data-threshold-line="excelling_proficiency_gte"
            x1="34"
            y1={@excelling_y}
            x2="254"
            y2={@excelling_y}
            class="stroke-white stroke-[2.3]"
          />
          <text
            x={@matrix_plot_left}
            y="258"
            text-anchor="middle"
            class="fill-Text-text-low-alpha text-[6.5px] font-bold"
          >
            0%
          </text>
          <text
            x="144"
            y="258"
            text-anchor="middle"
            class="fill-Text-text-low-alpha text-[6.5px] font-bold"
          >
            Progress
          </text>
          <text
            x="254"
            y="258"
            text-anchor="middle"
            class="fill-Text-text-low-alpha text-[6.5px] font-bold"
          >
            100%
          </text>
          <text
            x="24"
            y="244"
            text-anchor="end"
            class="fill-Text-text-low-alpha text-[6.5px] font-bold"
          >
            0%
          </text>
          <text
            x="24"
            y="24"
            text-anchor="end"
            class="fill-Text-text-low-alpha text-[6.5px] font-bold"
          >
            100%
          </text>
          <text
            x="14"
            y="130"
            text-anchor="middle"
            transform="rotate(-90 14 130)"
            class="fill-Text-text-low-alpha text-[6.5px] font-bold"
          >
            Proficiency
          </text>

          <.matrix_handle
            field={:struggling_progress_low_lt}
            axis="x"
            value={value(@draft, :struggling_progress_low_lt)}
            x={@low_x}
            y={@vertical_handle_bottom_y}
            role="struggling-progress-low-bottom"
            label="Struggling low progress bottom handle"
            tab_index="0"
          />
          <.matrix_handle
            field={:excelling_progress_gte}
            axis="x"
            value={value(@draft, :excelling_progress_gte)}
            x={@shared_progress_x}
            y={@vertical_handle_top_y}
            role="shared-progress-high-top"
            label="Shared high progress top handle"
            tab_index="0"
          />
          <.matrix_handle
            field={:excelling_proficiency_gte}
            axis="y"
            value={value(@draft, :excelling_proficiency_gte)}
            x={@horizontal_handle_right_x}
            y={@excelling_y}
            role="excelling-proficiency-right"
            label="Excelling proficiency right handle"
            tab_index="0"
          />
          <.matrix_handle
            field={:struggling_proficiency_lte}
            axis="y"
            value={value(@draft, :struggling_proficiency_lte)}
            x={@struggling_proficiency_left_handle_x}
            y={@struggling_y}
            role="struggling-proficiency-left"
            label="Struggling proficiency left region"
            tab_index="0"
          />
          <.matrix_handle
            field={:struggling_progress_low_lt}
            axis="x"
            value={value(@draft, :struggling_progress_low_lt)}
            x={@low_x}
            y={@vertical_handle_top_y}
            role="struggling-progress-low-top"
            label="Struggling low progress top handle"
          />
          <.matrix_handle
            field={:excelling_progress_gte}
            axis="x"
            value={value(@draft, :excelling_progress_gte)}
            x={@shared_progress_x}
            y={@vertical_handle_bottom_y}
            role="shared-progress-high-bottom"
            label="Shared high progress bottom handle"
          />
          <.matrix_handle
            field={:struggling_proficiency_lte}
            axis="y"
            value={value(@draft, :struggling_proficiency_lte)}
            x={@struggling_proficiency_right_handle_x}
            y={@struggling_y}
            role="struggling-proficiency-right"
            label="Struggling proficiency right region"
          />
          <.matrix_handle
            field={:excelling_proficiency_gte}
            axis="y"
            value={value(@draft, :excelling_proficiency_gte)}
            x={@horizontal_handle_left_x}
            y={@excelling_y}
            role="excelling-proficiency-left"
            label="Excelling proficiency left handle"
          />
        </svg>
      </div>
    </div>
    """
  end

  attr :field, :atom, required: true
  attr :axis, :string, required: true
  attr :value, :any, required: true
  attr :x, :any, required: true
  attr :y, :any, required: true
  attr :role, :string, required: true
  attr :label, :string, required: true
  attr :tab_index, :string, default: "-1"

  defp matrix_handle(assigns) do
    value = normalize_value(assigns.value)

    assigns =
      assigns
      |> assign(:numeric_value, value)
      |> assign(:handle_radius, @matrix_handle_radius)

    ~H"""
    <g
      tabindex={@tab_index}
      focusable={if @tab_index == "-1", do: "false", else: "true"}
      role="slider"
      aria-label={@label}
      aria-valuemin="0"
      aria-valuemax="100"
      aria-valuenow={@numeric_value}
      data-threshold-field={@field}
      data-axis={@axis}
      data-value={@numeric_value}
      data-handle-role={@role}
      class="cursor-pointer focus:outline-none"
    >
      <circle
        cx={@x}
        cy={@y}
        r={@handle_radius}
        class="matrix-handle-outer fill-[#3B3740] stroke-white stroke-[1.25]"
      />
      <circle cx={@x} cy={@y} r="2.45" class="matrix-handle-inner fill-[#F4F1F8] pointer-events-none" />
    </g>
    """
  end

  defp normalize_draft(nil), do: StudentSupportParameters.default_settings()

  defp normalize_draft(draft) when is_map(draft) do
    Map.merge(StudentSupportParameters.default_settings(), draft)
    |> sync_shared_progress_threshold()
  end

  defp value(draft, field), do: Map.get(draft, field, Map.get(draft, Atom.to_string(field)))

  defp normalize_value(value) when is_integer(value), do: value

  defp normalize_value(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> parsed
      _ -> 0
    end
  end

  defp normalize_value(_), do: 0

  defp field_label(:struggling_progress_low_lt), do: "Struggling progress <"
  defp field_label(:struggling_progress_high_gt), do: "Struggling progress >"
  defp field_label(:struggling_proficiency_lte), do: "Struggling proficiency ≤"
  defp field_label(:excelling_progress_gte), do: "Excelling progress ≥"
  defp field_label(:excelling_proficiency_gte), do: "Excelling proficiency ≥"

  defp matrix_geometry(draft) do
    low_x = matrix_x(draft, :struggling_progress_low_lt)
    shared_progress_x = matrix_x(draft, :excelling_progress_gte)
    struggling_y = matrix_y(draft, :struggling_proficiency_lte)
    excelling_y = matrix_y(draft, :excelling_proficiency_gte)

    %{
      low_x: low_x,
      shared_progress_x: shared_progress_x,
      struggling_y: struggling_y,
      excelling_y: excelling_y,
      struggling_left_width: low_x - @matrix_plot_left,
      struggling_right_width: @matrix_plot_left + @matrix_plot_size - shared_progress_x,
      struggling_height: @matrix_plot_top + @matrix_plot_size - struggling_y,
      excelling_width: @matrix_plot_left + @matrix_plot_size - shared_progress_x,
      excelling_height: excelling_y - @matrix_plot_top,
      vertical_handle_top_y: @matrix_plot_top + @matrix_handle_radius,
      vertical_handle_bottom_y: @matrix_plot_top + @matrix_plot_size - @matrix_handle_radius,
      struggling_proficiency_left_handle_x: @matrix_plot_left + @matrix_handle_radius,
      struggling_proficiency_right_handle_x:
        @matrix_plot_left + @matrix_plot_size - @matrix_handle_radius,
      horizontal_handle_left_x: @matrix_plot_left + @matrix_handle_radius,
      horizontal_handle_right_x: @matrix_plot_left + @matrix_plot_size - @matrix_handle_radius
    }
  end

  defp matrix_x(draft, field),
    do: @matrix_plot_left + normalize_value(value(draft, field)) * (@matrix_plot_size / 100)

  defp matrix_y(draft, field),
    do:
      @matrix_plot_top + @matrix_plot_size -
        normalize_value(value(draft, field)) * (@matrix_plot_size / 100)

  defp matrix_student_points(points, draft) do
    Enum.map(points, fn point ->
      Map.put(point, :class, matrix_point_class(point, draft))
    end)
  end

  defp matrix_point_class(point, draft) do
    progress_pct = Map.get(point, :progress_pct)
    proficiency_pct = Map.get(point, :proficiency_pct)
    shared_progress_threshold = normalize_value(value(draft, :excelling_progress_gte))

    cond do
      progress_pct >= shared_progress_threshold and
          proficiency_pct >= normalize_value(value(draft, :excelling_proficiency_gte)) ->
        "fill-Fill-Chart-fill-chart-purple-muted dark:fill-[#D96BEF]"

      (progress_pct < normalize_value(value(draft, :struggling_progress_low_lt)) or
         progress_pct > shared_progress_threshold) and
          proficiency_pct <= normalize_value(value(draft, :struggling_proficiency_lte)) ->
        "fill-[#FF9C54] dark:fill-[#FF9C54]"

      true ->
        "fill-Fill-Chart-fill-chart-blue-muted dark:fill-[#33CFE3]"
    end
  end

  defp sync_shared_progress_threshold(draft) do
    shared_value = value(draft, :excelling_progress_gte)

    draft
    |> Map.put(:excelling_progress_gte, shared_value)
    |> Map.put(:struggling_progress_high_gt, shared_value)
  end

  defp threshold_groups do
    [
      %{
        title: "Struggling",
        description: "Students who are showing low understanding of the material.",
        dot_class: "bg-Fill-Chart-fill-chart-orange-active",
        text_class: "text-Text-Chip-Orange",
        rows: [
          %{
            label: "Progress",
            controls: [
              %{field: :struggling_progress_low_lt, comparator: "<"},
              %{field: :struggling_progress_high_gt, comparator: ">"}
            ]
          },
          %{
            label: "Proficiency",
            controls: [%{field: :struggling_proficiency_lte, comparator: "≤"}]
          }
        ]
      },
      %{
        title: "Excelling",
        description: "Students who are consistently demonstrating strong understanding.",
        dot_class: "bg-Fill-Chart-fill-chart-purple-active",
        text_class: "text-Text-text-accent-purple",
        rows: [
          %{
            label: "Progress",
            controls: [%{field: :excelling_progress_gte, comparator: "≥"}]
          },
          %{
            label: "Proficiency",
            controls: [%{field: :excelling_proficiency_gte, comparator: "≥"}]
          }
        ]
      },
      %{
        title: "On track",
        description:
          "Students whose progress and understanding fall between struggling and excelling.",
        dot_class: "bg-Fill-Chart-fill-chart-blue-active",
        text_class: "text-Fill-Chart-fill-chart-blue-active",
        rows: []
      }
    ]
  end

  defp field_error(changeset, field) do
    changeset.errors
    |> Keyword.get_values(field)
    |> List.first()
    |> case do
      {message, _opts} -> message
      _ -> nil
    end
  end

  defp field_invalid?(changeset, field), do: not is_nil(field_error(changeset, field))

  defp input_description_ids(changeset, field) do
    suffix_id = "student-support-parameters-#{field}-suffix"

    if field_invalid?(changeset, field) do
      "#{suffix_id} student-support-parameters-#{field}-error"
    else
      suffix_id
    end
  end

  defp error_message(:save_failed), do: "Could not save student support parameters."

  defp error_message(:reprojection_failed),
    do: "Settings were saved, but Student Support could not refresh."

  defp error_message(_), do: "Could not update student support parameters."
end
