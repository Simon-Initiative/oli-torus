defmodule OliWeb.Sections.AssessmentSettings.StudentExceptionsTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.FormatDateTime
  use Phoenix.Component

  def new(
        student_exceptions,
        section_slug,
        selected_assessment,
        target,
        selected_student_exceptions,
        ctx
      ) do
    column_specs = [
      %ColumnSpec{
        name: :student,
        label: "STUDENT",
        render_fn: &__MODULE__.render_student_column/3,
        th_class: "pl-10 instructor_dashboard_th sticky left-0 bg-white dark:bg-neutral-800 z-10",
        td_class: "sticky left-0 bg-white dark:bg-neutral-800 z-10 whitespace-nowrap"
      },
      %ColumnSpec{
        name: :due_date,
        label: "DUE DATE",
        render_fn: &__MODULE__.render_due_date_column/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :max_attempts,
        label: "# ATTEMPTS",
        render_fn: &__MODULE__.render_attempts_column/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :time_limit,
        label: "TIME LIMIT",
        render_fn: &__MODULE__.render_time_limit_column/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :late_submit,
        label: "LATE SUBMIT",
        render_fn: &__MODULE__.render_late_submit_column/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :late_start,
        label: "LATE START",
        render_fn: &__MODULE__.render_late_start_column/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :scoring_strategy_id,
        label: "SCORING",
        render_fn: &__MODULE__.render_scoring_column/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :grace_period,
        label: "GRACE PERIOD",
        render_fn: &__MODULE__.render_grace_period_column/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :retake_mode,
        label: "RETAKE MODE",
        render_fn: &__MODULE__.render_retake_mode_column/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :feedback_mode,
        label: "VIEW FEEDBACK",
        render_fn: &__MODULE__.render_view_feedback_column/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :review_submission,
        label: "VIEW ANSWERS",
        render_fn: &__MODULE__.render_view_answers_column/3,
        th_class: "instructor_dashboard_th"
      }
    ]

    SortableTableModel.new(
      rows: student_exceptions,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:user_id],
      data: %{
        section_slug: section_slug,
        selected_assessment: selected_assessment,
        target: target,
        selected_student_exceptions: selected_student_exceptions,
        ctx: ctx
      }
    )
  end

  def render_student_column(assigns, student_exception, _) do
    assigns =
      Map.merge(assigns, %{name: student_exception.user.name, id: student_exception.user_id})

    ~H"""
      <div class="pl-1 pr-4">
        <input class="mr-2" type="checkbox" checked={@id in @selected_student_exceptions} name={"checkbox-#{@id}"} />
        <%= @name %>
      </div>
    """
  end

  def render_due_date_column(assigns, student_exception, _) do
    assigns =
      Map.merge(assigns, %{
        due_date: student_exception.end_date,
        id: student_exception.user_id
      })

    ~H"""
    <div class={data_class(@selected_assessment.end_date, @due_date)}>
      <%= if @selected_assessment.scheduling_type == :due_by do %>
        <input name={"end_date-#{@id}"} type="datetime-local" phx-debounce={500} value={value_from_datetime(@due_date, @ctx)} placeholder="-" />
      <% else %>
        No due date
      <% end %>
    </div>
    """
  end

  def render_attempts_column(assigns, student_exception, _) do
    assigns =
      Map.merge(assigns, %{
        max_attempts: student_exception.max_attempts,
        id: student_exception.user_id
      })

    ~H"""
    <div class={data_class(@selected_assessment.max_attempts, @max_attempts)}>
      <div class="relative">
        <input class="w-28" type="number" min="0" value={@max_attempts} placeholder="-" phx-debounce={300} name={"max_attempts-#{@id}"} />
        <%= if @max_attempts == 0 do %>
          <span class="text-[10px] absolute -ml-20 mt-3">(Unlimited)</span>
        <% end %>
      </div>
    </div>
    """
  end

  def render_time_limit_column(assigns, student_exception, _) do
    assigns =
      Map.merge(assigns, %{
        time_limit: student_exception.time_limit,
        id: student_exception.user_id
      })

    ~H"""
    <div class={data_class(@selected_assessment.time_limit, @time_limit)}>
      <div class="relative">
        <input class="w-28" type="number" min="0" value={@time_limit} placeholder="-" phx-debounce={300} name={"time_limit-#{@id}"} />
        <%= if @time_limit == 0 do %>
          <span class="text-[10px] absolute -ml-20 mt-3">(Unlimited)</span>
        <% end %>
      </div>
    </div>
    """
  end

  def render_late_submit_column(assigns, student_exception, _) do
    assigns =
      Map.merge(assigns, %{
        late_submit: student_exception.late_submit,
        id: student_exception.user_id
      })

    ~H"""
    <div class={data_class(@selected_assessment.late_submit, @late_submit)}>
      <select class="torus-select pr-32" name={"late_submit-#{@id}"}>
        <option disabled selected={@late_submit == nil} hidden value="">-</option>
        <option selected={@late_submit == :allow} value={:allow}>Allow</option>
        <option selected={@late_submit == :disallow} value={:disallow}>Disallow</option>
      </select>
    </div>
    """
  end

  def render_late_start_column(assigns, student_exception, _) do
    assigns =
      Map.merge(assigns, %{
        late_start: student_exception.late_start,
        id: student_exception.user_id
      })

    ~H"""
    <div class={data_class(@selected_assessment.late_start, @late_start)}>
      <select class="torus-select pr-32" name={"late_start-#{@id}"}>
        <option disabled selected={@late_start == nil} hidden value="">-</option>
        <option selected={@late_start == :allow} value={:allow}>Allow</option>
        <option selected={@late_start == :disallow} value={:disallow}>Disallow</option>
      </select>
    </div>
    """
  end

  def render_scoring_column(assigns, student_exception, _) do
    assigns =
      Map.merge(assigns, %{
        scoring_strategy_id: student_exception.scoring_strategy_id,
        id: student_exception.user_id
      })

    ~H"""
    <div class={data_class(@selected_assessment.scoring_strategy_id, @scoring_strategy_id)}>
      <select class="torus-select pr-32" name={"scoring_strategy_id-#{@id}"}>
        <option disabled selected={@scoring_strategy_id == nil} hidden value="">-</option>
        <option selected={@scoring_strategy_id == 1} value={1}>Average</option>
        <option selected={@scoring_strategy_id == 2} value={2}>Best</option>
        <option selected={@scoring_strategy_id == 3} value={3}>Last</option>
      </select>
    </div>
    """
  end

  def render_grace_period_column(assigns, student_exception, _) do
    assigns =
      Map.merge(assigns, %{
        grace_period: student_exception.grace_period,
        id: student_exception.user_id
      })

    ~H"""
    <div class={data_class(@selected_assessment.grace_period, @grace_period)}>
      <input class="w-28" type="number" min="0" value={@grace_period} placeholder="-" phx-debounce={500} name={"grace_period-#{@id}"} />
    </div>
    """
  end

  def render_retake_mode_column(assigns, student_exception, _) do
    assigns =
      Map.merge(assigns, %{
        retake_mode: student_exception.retake_mode,
        id: student_exception.user_id
      })

    ~H"""
    <div class={data_class(@selected_assessment.retake_mode, @retake_mode)}>
      <select class="torus-select pr-32" name={"retake_mode-#{@id}"}>
        <option disabled selected={@retake_mode == nil} hidden value="">-</option>
        <option selected={@retake_mode == :targeted} value={:targeted}>Targeted</option>
        <option selected={@retake_mode == :normal} value={:normal}>Normal</option>
      </select>
    </div>
    """
  end

  def render_view_feedback_column(assigns, student_exception, _) do
    assigns =
      Map.merge(assigns, %{
        feedback_mode: student_exception.feedback_mode,
        id: student_exception.user_id
      })

    ~H"""
    <div class={data_class(@selected_assessment.feedback_mode, @feedback_mode)}>
      <select class="torus-select pr-32" name={"feedback_mode-#{@id}"}>
        <option disabled selected={@feedback_mode == nil} hidden value="">-</option>
        <option selected={@feedback_mode == :allow} value={:allow}>Allow</option>
        <option selected={@feedback_mode == :disallow} value={:disallow}>Disallow</option>
        <option selected={@feedback_mode == :scheduled} value={:scheduled}>Scheduled</option>
      </select>
    </div>
    """
  end

  def render_view_answers_column(assigns, student_exception, _) do
    assigns =
      Map.merge(assigns, %{
        review_submission: student_exception.review_submission,
        id: student_exception.user_id
      })

    ~H"""
    <div class={data_class(@selected_assessment.review_submission, @review_submission)}>
      <select class="torus-select pr-32" name={"review_submission-#{@id}"}>
        <option disabled selected={@review_submission == nil} hidden value="">-</option>
        <option selected={@review_submission == :allow} value={:allow}>Allow</option>
        <option selected={@review_submission == :disallow} value={:disallow}>Disallow</option>
      </select>
    </div>
    """
  end

  defp data_class(assessment_data, student_exception_data)
       when assessment_data != student_exception_data and student_exception_data != nil,
       do: "highlight-exception"

  defp data_class(_assessment_data, _student_exception_data), do: ""

  defp value_from_datetime(nil, _ctx), do: nil

  defp value_from_datetime(datetime, ctx) do
    datetime
    |> FormatDateTime.convert_datetime(ctx)
    |> DateTime.to_iso8601()
    |> String.slice(0, 16)
  end
end
