defmodule OliWeb.Sections.AssessmentSettings.SettingsTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Delivery.Instructor.PreviewRoutes
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Sections.AssessmentSettings.Tooltips
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  use Phoenix.Component

  @adaptive_setting_disabled_tooltip "This setting does not apply to adaptive pages"
  @scoring_mode_locked_tooltip "Students have already started this assignment. Scoring mode can no longer be changed."

  def new(
        assessments,
        section_slug,
        ctx,
        on_edit_date,
        on_edit_password,
        on_no_edit_password,
        edit_password_id \\ nil,
        opts \\ []
      ) do
    column_specs = [
      %ColumnSpec{
        name: :index,
        label: "#",
        th_class: "pl-10 !sticky left-0 !bg-Table-table-top-row z-10 whitespace-nowrap w-20",
        td_class: "sticky pl-11 left-0 bg-Background-bg-secondary z-10 whitespace-nowrap w-20",
        tooltip: Tooltips.for(:index)
      },
      %ColumnSpec{
        name: :name,
        label: "ASSESSMENT",
        render_fn: &render_assessment_column/3,
        th_class: "!sticky left-20 !bg-Table-table-top-row z-10",
        td_class: "sticky left-20 !bg-Background-bg-secondary z-10 whitespace-nowrap",
        tooltip: Tooltips.for(:name)
      },
      %ColumnSpec{
        name: :available_date,
        label: "AVAILABLE DATE",
        render_fn: &render_available_date_column/3,
        th_class: "whitespace-nowrap",
        tooltip: Tooltips.for(:available_date)
      },
      %ColumnSpec{
        name: :due_date,
        label: "DUE DATE",
        render_fn: &render_due_date_column/3,
        th_class: "whitespace-nowrap",
        tooltip: Tooltips.for(:due_date)
      },
      %ColumnSpec{
        name: :max_attempts,
        label: "# ATTEMPTS",
        render_fn: &render_attempts_column/3,
        th_class: "whitespace-nowrap",
        tooltip: Tooltips.for(:max_attempts)
      },
      %ColumnSpec{
        name: :time_limit,
        label: "TIME LIMIT",
        render_fn: &render_time_limit_column/3,
        th_class: "whitespace-nowrap",
        tooltip: Tooltips.for(:time_limit)
      },
      %ColumnSpec{
        name: :late_policy,
        label: "LATE POLICY",
        render_fn: &render_late_policy_column/3,
        th_class: "whitespace-nowrap",
        tooltip: Tooltips.for(:late_policy)
      },
      %ColumnSpec{
        name: :scoring_strategy_id,
        label: "SCORING STRATEGY",
        render_fn: &render_scoring_column/3,
        th_class: "whitespace-nowrap",
        tooltip: Tooltips.for(:scoring_strategy_id)
      },
      %ColumnSpec{
        name: :grace_period,
        label: "GRACE PERIOD",
        render_fn: &render_grace_period_column/3,
        th_class: "whitespace-nowrap",
        tooltip: Tooltips.for(:grace_period)
      },
      %ColumnSpec{
        name: :retake_mode,
        label: "RETAKE MODE",
        render_fn: &render_retake_mode_column/3,
        th_class: "whitespace-nowrap",
        tooltip: Tooltips.for(:retake_mode)
      },
      %ColumnSpec{
        name: :assessment_mode,
        label: "PRESENTATION",
        render_fn: &render_assessment_mode_column/3,
        th_class: "whitespace-nowrap",
        tooltip: Tooltips.for(:assessment_mode)
      },
      %ColumnSpec{
        name: :batch_scoring,
        label: "SCORING MODE",
        render_fn: &render_batch_scoring/3,
        th_class: "whitespace-nowrap",
        tooltip: Tooltips.for(:batch_scoring),
        tooltip_id: "assessment-settings-batch-scoring-column-tooltip",
        tooltip_icon: true
      },
      %ColumnSpec{
        name: :replacement_strategy,
        label: "REPLACEMENT",
        render_fn: &render_replacement/3,
        th_class: "whitespace-nowrap",
        tooltip: Tooltips.for(:replacement_strategy)
      },
      %ColumnSpec{
        name: :feedback_mode,
        label: "VIEW FEEDBACK",
        render_fn: &render_view_feedback_column/3,
        th_class: "whitespace-nowrap",
        tooltip: Tooltips.for(:feedback_mode)
      },
      %ColumnSpec{
        name: :review_submission,
        label: "VIEW ANSWERS",
        render_fn: &render_view_answers_column/3,
        th_class: "whitespace-nowrap",
        tooltip: Tooltips.for(:review_submission)
      },
      %ColumnSpec{
        name: :password,
        label: "PASSWORD",
        render_fn: &render_password_column/3,
        th_class: "pt-3 whitespace-nowrap",
        sortable: false,
        tooltip: Tooltips.for(:password)
      },
      %ColumnSpec{
        name: :exceptions_count,
        label: "EXCEPTIONS",
        render_fn: &render_exceptions_column/3,
        th_class: "whitespace-nowrap",
        tooltip: Tooltips.for(:exceptions_count)
      },
      %ColumnSpec{
        name: :allow_hints,
        label: "ALLOW HINTS",
        render_fn: &render_allow_hints_column/3,
        th_class: "whitespace-nowrap"
      }
    ]

    column_specs =
      if Keyword.get(opts, :include_student_exceptions?, true),
        do: column_specs,
        else: Enum.reject(column_specs, &(&1.name == :exceptions_count))

    SortableTableModel.new(
      rows: assessments,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:resource_id],
      data: %{
        section_slug: section_slug,
        ctx: ctx,
        on_edit_date: on_edit_date,
        on_edit_password: on_edit_password,
        on_no_edit_password: on_no_edit_password,
        edit_password_id: edit_password_id,
        return_to: Keyword.fetch!(opts, :return_to)
      }
    )
  end

  def render_assessment_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        name: assessment.name,
        href:
          PreviewRoutes.lesson_path(
            assigns.section_slug,
            assessment.revision_slug,
            return_to: assigns.return_to
          )
      })

    ~H"""
    <div class="pr-4">
      <a
        href={@href}
        class="text-Text-text-high hover:text-Text-text-high hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Text-text-link"
        aria-label={"Open #{@name} in Instructor View"}
      >
        {@name}
      </a>
    </div>
    """
  end

  def render_available_date_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        available_date: assessment.start_date,
        id: assessment.resource_id
      })

    ~H"""
    <button
      class="hover:underline whitespace-nowrap"
      type="button"
      phx-click={edit_date_and_show_modal(@on_edit_date, "available_date")}
      phx-value-assessment_id={@id}
    >
      <%= if is_nil(@available_date) do %>
        Always available
      <% else %>
        {value_from_datetime(@available_date, @ctx)}
      <% end %>
    </button>
    """
  end

  def render_due_date_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        due_date: assessment.end_date,
        id: assessment.resource_id,
        scheduling_type: assessment.scheduling_type
      })

    ~H"""
    <button
      class="hover:underline whitespace-nowrap"
      type="button"
      phx-click={edit_date_and_show_modal(@on_edit_date, "due_date")}
      phx-value-assessment_id={@id}
    >
      <%= if @due_date != nil and @scheduling_type == :due_by do %>
        {value_from_datetime(@due_date, @ctx)}
      <% else %>
        No due date
      <% end %>
    </button>
    """
  end

  def render_attempts_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{max_attempts: assessment.max_attempts, id: assessment.resource_id})

    ~H"""
    <div class="relative">
      <input
        class="mr-3 w-28"
        type="number"
        min="0"
        value={@max_attempts}
        phx-debounce={300}
        name={"max_attempts-#{@id}"}
      />
      <%= if @max_attempts == 0 do %>
        <span class="text-[10px] absolute -ml-24 mt-3">(Unlimited)</span>
      <% end %>
    </div>
    """
  end

  def render_time_limit_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{time_limit: assessment.time_limit, id: assessment.resource_id})

    ~H"""
    <div class="relative">
      <input
        class="mr-3 w-28"
        type="number"
        min="0"
        value={@time_limit}
        phx-debounce={300}
        name={"time_limit-#{@id}"}
      />
      <%= if @time_limit == 0 do %>
        <span class="text-[10px] absolute -ml-24 mt-3">(Unlimited)</span>
      <% end %>
    </div>
    """
  end

  def render_late_policy_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        late_start: assessment.late_start,
        late_submit: assessment.late_submit,
        id: assessment.resource_id
      })

    ~H"""
    <select class="torus-select pr-32" name={"late_policy-#{@id}"}>
      <option
        selected={@late_start == :allow && @late_submit == :allow}
        value={:allow_late_start_and_late_submit}
      >
        Allow late start and late submit
      </option>
      <option
        selected={@late_start == :disallow && @late_submit == :allow}
        value={:allow_late_submit_but_not_late_start}
      >
        Allow late submit but not late start
      </option>
      <option
        selected={@late_start == :disallow && @late_submit == :disallow}
        value={:disallow_late_start_and_late_submit}
      >
        Disallow late start and late submit
      </option>
    </select>
    """
  end

  def render_replacement(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        replacement_strategy: assessment.replacement_strategy,
        id: assessment.resource_id,
        is_adaptive: adaptive_page?(assessment)
      })

    ~H"""
    <.adaptive_setting_wrapper disabled={@is_adaptive} id={"replacement_strategy-wrapper-#{@id}"}>
      <.static_disabled_select
        :if={@is_adaptive}
        label={replacement_strategy_label(@replacement_strategy)}
      />
      <select
        :if={!@is_adaptive}
        class="torus-select pr-32"
        name={"replacement_strategy-#{@id}"}
      >
        <option selected={@replacement_strategy == :none} value={:none}>
          All questions remain the same for all attempts
        </option>
        <option selected={@replacement_strategy == :dynamic} value={:dynamic}>
          Dynamic questions regenerate a new question
        </option>
      </select>
    </.adaptive_setting_wrapper>
    """
  end

  def render_scoring_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        scoring_strategy_id: assessment.scoring_strategy_id,
        id: assessment.resource_id
      })

    ~H"""
    <select
      class="torus-select pr-32"
      name={"scoring_strategy_id-#{@id}"}
      id={"scoring_strategy_id-#{@id}"}
    >
      <option disabled selected={@scoring_strategy_id == nil} hidden value="">-</option>
      <option selected={@scoring_strategy_id == 1} value={1}>Average</option>
      <option selected={@scoring_strategy_id == 2} value={2}>Best</option>
      <option selected={@scoring_strategy_id == 3} value={3}>Most Recent</option>
    </select>
    """
  end

  def render_grace_period_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{grace_period: assessment.grace_period, id: assessment.resource_id})

    ~H"""
    <input
      class="w-28"
      type="number"
      min="0"
      value={@grace_period}
      phx-debounce={500}
      name={"grace_period-#{@id}"}
    />
    """
  end

  def render_retake_mode_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        retake_mode: assessment.retake_mode,
        id: assessment.resource_id,
        is_adaptive: adaptive_page?(assessment)
      })

    ~H"""
    <.adaptive_setting_wrapper disabled={@is_adaptive} id={"retake_mode-wrapper-#{@id}"}>
      <.static_disabled_select :if={@is_adaptive} label={retake_mode_label(@retake_mode)} />
      <select
        :if={!@is_adaptive}
        class="torus-select pr-32"
        name={"retake_mode-#{@id}"}
      >
        <option selected={@retake_mode == :targeted} value={:targeted}>Targeted</option>
        <option selected={@retake_mode == :normal} value={:normal}>Normal</option>
      </select>
    </.adaptive_setting_wrapper>
    """
  end

  def render_assessment_mode_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        assessment_mode: assessment.assessment_mode,
        id: assessment.resource_id,
        is_adaptive: adaptive_page?(assessment)
      })

    ~H"""
    <.adaptive_setting_wrapper disabled={@is_adaptive} id={"assessment_mode-wrapper-#{@id}"}>
      <.static_disabled_select
        :if={@is_adaptive}
        label={assessment_mode_label(@assessment_mode)}
      />
      <select
        :if={!@is_adaptive}
        class="torus-select pr-32"
        name={"assessment_mode-#{@id}"}
      >
        <option selected={@assessment_mode == :traditional} value={:traditional}>Traditional</option>
        <option selected={@assessment_mode == :one_at_a_time} value={:one_at_a_time}>
          One at a time
        </option>
      </select>
    </.adaptive_setting_wrapper>
    """
  end

  def render_view_feedback_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        feedback_mode: assessment.feedback_mode,
        id: assessment.resource_id,
        is_adaptive: adaptive_page?(assessment)
      })

    ~H"""
    <.adaptive_setting_wrapper disabled={@is_adaptive} id={"feedback_mode-wrapper-#{@id}"}>
      <.static_disabled_select :if={@is_adaptive} label={feedback_mode_label(@feedback_mode)} />
      <select
        :if={!@is_adaptive}
        class="torus-select pr-32"
        name={"feedback_mode-#{@id}"}
      >
        <option selected={@feedback_mode == :allow} value={:allow}>Allow</option>
        <option selected={@feedback_mode == :disallow} value={:disallow}>Disallow</option>
        <option selected={@feedback_mode == :scheduled} value={:scheduled}>Scheduled</option>
      </select>
    </.adaptive_setting_wrapper>
    """
  end

  def render_view_answers_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        review_submission: assessment.review_submission,
        id: assessment.resource_id,
        is_adaptive: adaptive_page?(assessment)
      })

    ~H"""
    <.adaptive_setting_wrapper disabled={@is_adaptive} id={"review_submission-wrapper-#{@id}"}>
      <.static_disabled_select
        :if={@is_adaptive}
        label={review_submission_label(@review_submission)}
      />
      <select
        :if={!@is_adaptive}
        class="torus-select pr-32"
        name={"review_submission-#{@id}"}
      >
        <option selected={@review_submission == :allow} value={:allow}>Allow</option>
        <option selected={@review_submission == :disallow} value={:disallow}>Disallow</option>
      </select>
    </.adaptive_setting_wrapper>
    """
  end

  def render_password_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        password: assessment.password,
        id: assessment.resource_id
      })

    ~H"""
    <%= if @password in ["", nil] do %>
      <input
        class="w-40"
        type="text"
        placeholder="Enter password"
        phx-debounce={800}
        name={"password-#{@id}"}
      />
    <% else %>
      <%= if @id == @edit_password_id do %>
        <input
          id={"password_input#{@id}"}
          class="w-40"
          type="text"
          value={@password}
          phx-hook="InputAutoSelect"
          phx-click-away={@on_no_edit_password}
          phx-debounce={800}
          name={"password-#{@id}"}
        />
      <% else %>
        <button
          type="button"
          phx-click={@on_edit_password}
          phx-value-assessment_id={@id}
          role="edit_password"
        >
          <input class="w-40" type="password" value={hide_password(@password)} />
        </button>
      <% end %>
    <% end %>
    """
  end

  defp hide_password(password) do
    String.replace(password, ~r/./, "*")
  end

  def render_exceptions_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        exceptions_count: assessment.exceptions_count,
        id: assessment.resource_id
      })

    ~H"""
    <div>
      <.link
        class="ml-6 underline"
        navigate={
          Routes.live_path(
            OliWeb.Endpoint,
            OliWeb.Sections.AssessmentSettings.StudentExceptionsLive,
            @section_slug,
            @id
          )
        }
      >
        {@exceptions_count}
      </.link>
    </div>
    """
  end

  def render_batch_scoring(assigns, assessment, _) do
    is_adaptive = adaptive_page?(assessment)
    scoring_mode_locked = scoring_mode_locked?(assessment)
    disabled = is_adaptive or scoring_mode_locked

    assigns =
      Map.merge(assigns, %{
        batch_scoring: assessment.batch_scoring,
        batch_scoring_label: batch_scoring_label(assessment.batch_scoring),
        id: assessment.resource_id,
        is_adaptive: is_adaptive,
        disabled: disabled,
        scoring_mode_locked: scoring_mode_locked,
        tooltip_text:
          if(is_adaptive,
            do: @adaptive_setting_disabled_tooltip,
            else: @scoring_mode_locked_tooltip
          )
      })

    ~H"""
    <.adaptive_setting_wrapper
      disabled={@disabled}
      id={"batch_scoring-wrapper-#{@id}"}
      tooltip_text={@tooltip_text}
    >
      <div class="flex items-center gap-2">
        <.static_disabled_select
          :if={@disabled}
          label={@batch_scoring_label}
          locked={@scoring_mode_locked and !@is_adaptive}
        />
        <select
          :if={!@disabled}
          class="torus-select pr-32"
          name={"batch_scoring-#{@id}"}
        >
          <option selected={@batch_scoring} value="true">Score at the end</option>
          <option selected={!@batch_scoring} value="false">Score as you go</option>
        </select>
      </div>
    </.adaptive_setting_wrapper>
    """
  end

  defp batch_scoring_label(true), do: "Score at the end"
  defp batch_scoring_label(false), do: "Score as you go"

  attr(:label, :string, required: true)
  attr(:locked, :boolean, default: false)
  attr(:disabled_reason, :string, default: @adaptive_setting_disabled_tooltip)

  defp static_disabled_select(assigns) do
    ~H"""
    <div
      class="inline-flex min-h-[26px] min-w-[178px] items-center border-b-2 border-Text-text-low-alpha text-Text-text-low-alpha"
      aria-disabled="true"
      aria-label={disabled_select_aria_label(assigns)}
      role="group"
    >
      <div class="flex min-w-0 flex-1 items-center gap-1">
        <Icons.lock :if={@locked} class="h-5 w-5 shrink-0 text-Text-text-low-alpha" />
        <span class="min-w-0 truncate whitespace-nowrap text-base font-semibold leading-6">
          {@label}
        </span>
      </div>
      <Icons.chevron_down
        width="24"
        height="24"
        class="h-6 w-6 shrink-0 text-Text-text-low-alpha"
      />
    </div>
    """
  end

  defp disabled_select_aria_label(%{locked: true, label: label}) do
    "Locked setting: #{label}. Locked because students have started this assignment."
  end

  defp disabled_select_aria_label(%{label: label, disabled_reason: reason})
       when is_binary(reason) and reason != "" do
    "Disabled setting: #{label}. #{reason}"
  end

  defp disabled_select_aria_label(%{label: label}), do: "Disabled setting: #{label}"

  slot(:inner_block, required: true)
  attr(:disabled, :boolean, required: true)
  attr(:id, :string, required: true)
  attr(:tooltip_text, :string, default: @adaptive_setting_disabled_tooltip)

  defp adaptive_setting_wrapper(assigns) do
    ~H"""
    <div
      id={@id}
      class={if @disabled, do: "inline-block cursor-not-allowed", else: "inline-block"}
      phx-hook={if @disabled, do: "GlobalTooltip"}
      data-tooltip={if @disabled, do: @tooltip_text}
      data-tooltip-style={if @disabled, do: "body"}
      aria-describedby={if @disabled, do: "#{@id}-description"}
      tabindex={if @disabled, do: "0"}
    >
      {render_slot(@inner_block)}
      <span :if={@disabled} id={"#{@id}-description"} class="sr-only">
        {@tooltip_text}
      </span>
    </div>
    """
  end

  defp adaptive_page?(%{is_adaptive: true}), do: true
  defp adaptive_page?(_), do: false

  defp scoring_mode_locked?(%{has_student_attempts: true}), do: true
  defp scoring_mode_locked?(_), do: false

  defp replacement_strategy_label(:dynamic), do: "Dynamic questions regenerate a new question"
  defp replacement_strategy_label(_), do: "All questions remain the same for all attempts"

  defp retake_mode_label(:normal), do: "Normal"
  defp retake_mode_label(_), do: "Targeted"

  defp assessment_mode_label(:one_at_a_time), do: "One at a time"
  defp assessment_mode_label(_), do: "Traditional"

  defp feedback_mode_label(:disallow), do: "Disallow"
  defp feedback_mode_label(:scheduled), do: "Scheduled"
  defp feedback_mode_label(_), do: "Allow"

  defp review_submission_label(:disallow), do: "Disallow"
  defp review_submission_label(_), do: "Allow"

  def render_allow_hints_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        allow_hints: assessment.allow_hints,
        id: assessment.resource_id
      })

    ~H"""
    <select class="torus-select pr-32" name={"allow_hints-#{@id}"}>
      <option selected={@allow_hints} value="true">Allow</option>
      <option selected={!@allow_hints} value="false">Disallow</option>
    </select>
    """
  end

  defp value_from_datetime(nil, _ctx), do: nil

  defp value_from_datetime(datetime, ctx) do
    datetime
    |> FormatDateTime.date(ctx: ctx, show_timezone: false)
  end

  defp edit_date_and_show_modal(on_edit_date, date_input_type),
    do: JS.push(on_edit_date, "open", target: "#assessment_#{date_input_type}_modal")
end
