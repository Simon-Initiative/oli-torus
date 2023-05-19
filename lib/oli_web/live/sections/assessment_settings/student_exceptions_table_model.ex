defmodule OliWeb.Sections.AssessmentSettings.StudentExceptionsTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Utils
  use Phoenix.Component

  def new(student_exceptions, section_slug, selected_assessment, target) do
    column_specs = [
      %ColumnSpec{
        name: :student,
        label: "STUDENT",
        render_fn: &__MODULE__.render_student_column/3,
        th_class: "pl-10 instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :due_date,
        label: "DUE DATE",
        render_fn: &__MODULE__.render_due_date_column/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :attempts,
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
        name: :scoring,
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
        name: :view_feedback,
        label: "VIEW FEEDBACK",
        render_fn: &__MODULE__.render_view_feedback_column/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :view_answers,
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
        target: target
      }
    )
  end

  def render_student_column(assigns, student_exception, _) do
    assigns =
      Map.merge(assigns, %{name: student_exception.user.name, id: student_exception.user_id})

    ~H"""
      <div class="pl-9">
      <input type="checkbox" phx-click="row_selected" phx-target={@target} phx-value-user_id={@id}/>
      <%= @name %>

      </div>
    """
  end

  def render_due_date_column(assigns, student_exception, _) do
    assigns = Map.merge(assigns, %{due_date: student_exception.end_date})

    ~H"""
    <div class={data_class(@selected_assessment.end_date, @due_date)}><%= @due_date %></div>
    """
  end

  def render_attempts_column(assigns, student_exception, _) do
    assigns = Map.merge(assigns, %{attempts: student_exception.max_attempts})

    ~H"""
    <div class={data_class(@selected_assessment.max_attempts, @attempts)}><%= @attempts %></div>
    """
  end

  def render_time_limit_column(assigns, student_exception, _) do
    assigns = Map.merge(assigns, %{time_limit: student_exception.time_limit})

    ~H"""
    <div><%= @time_limit %></div>
    """
  end

  def render_late_submit_column(assigns, student_exception, _) do
    assigns = Map.merge(assigns, %{late_submit: student_exception.late_submit})

    ~H"""
    <div><%= @late_submit %></div>
    """
  end

  def render_late_start_column(assigns, student_exception, _) do
    assigns = Map.merge(assigns, %{late_start: student_exception.late_start})

    ~H"""
    <div><%= @late_start %></div>
    """
  end

  def render_scoring_column(assigns, student_exception, _) do
    assigns = Map.merge(assigns, %{scoring: student_exception.scoring_strategy_id})

    ~H"""
    <div><%= @scoring %></div>
    """
  end

  def render_grace_period_column(assigns, student_exception, _) do
    assigns = Map.merge(assigns, %{grace_period: student_exception.grace_period})

    ~H"""
    <div><%= @grace_period %></div>
    """
  end

  def render_retake_mode_column(assigns, student_exception, _) do
    assigns = Map.merge(assigns, %{retake_mode: student_exception.retake_mode})

    ~H"""
    <div><%= @retake_mode %></div>
    """
  end

  def render_view_feedback_column(assigns, student_exception, _) do
    assigns = Map.merge(assigns, %{view_feedback: student_exception.feedback_mode})

    ~H"""
    <div><%= @view_feedback %></div>
    """
  end

  def render_view_answers_column(assigns, student_exception, _) do
    assigns = Map.merge(assigns, %{view_answers: student_exception.feedback_scheduled_date})

    ~H"""
    <div><%= @view_answers %></div>
    """
  end

  defp data_class(assessment_data, student_exception_data)
       when assessment_data != student_exception_data,
       do: "bg-green-300"

  defp data_class(_assessment_data, _student_exception_data), do: ""
end
