defmodule OliWeb.Sections.AssessmentSettings.SettingsTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  use Phoenix.Component

  def new(assessments, section_slug) do
    column_specs = [
      %ColumnSpec{
        name: :assessment,
        label: "ASSESSMENT",
        render_fn: &__MODULE__.render_assessment_column/3,
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
      },
      %ColumnSpec{
        name: :exceptions,
        label: "EXCEPTIONS",
        render_fn: &__MODULE__.render_exceptions_column/3,
        th_class: "instructor_dashboard_th"
      }
    ]

    SortableTableModel.new(
      rows: assessments,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{
        section_slug: section_slug
      }
    )
  end

  def render_assessment_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{assessment: assessment.name})

    ~H"""
      <div class="pl-9"><%= @assessment %></div>
    """
  end

  def render_due_date_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{due_date: assessment.end_date})

    ~H"""
    <div><%= @due_date %></div>
    """
  end

  def render_attempts_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{attempts: assessment.max_attempts})

    ~H"""
      <select class="torus-select pr-32" name="attempts">
        <option selected={false} value={"all"}>All</option>
        <option selected={true} value={5}><%= @attempts %></option>
      </select>
    """
  end

  def render_time_limit_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{time_limit: assessment.time_limit})

    ~H"""
    <div><%= @time_limit %></div>
    """
  end

  def render_late_submit_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{late_submit: assessment.late_submit})

    ~H"""
    <div><%= @late_submit %></div>
    """
  end

  def render_late_start_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{late_start: assessment.late_start})

    ~H"""
    <div><%= @late_start %></div>
    """
  end

  def render_scoring_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{scoring: assessment.scoring_strategy_id})

    ~H"""
    <div><%= @scoring %></div>
    """
  end

  def render_grace_period_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{grace_period: assessment.grace_period})

    ~H"""
    <div><%= @grace_period %></div>
    """
  end

  def render_retake_mode_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{retake_mode: assessment.retake_mode})

    ~H"""
    <div><%= @retake_mode %></div>
    """
  end

  def render_view_feedback_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{view_feedback: assessment.feedback_mode})

    ~H"""
    <div><%= @view_feedback %></div>
    """
  end

  def render_view_answers_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{view_answers: assessment.feedback_scheduled_date})

    ~H"""
    <div><%= @view_answers %></div>
    """
  end

  def render_exceptions_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        exceptions_count: assessment.exceptions_count,
        assessment_id: assessment.resource_id
      })

    ~H"""
    <div>
      <%= if @exceptions_count > 0 do %>
        <.link
          class="ml-6 text-gray-600 underline hover:text-gray-700"
          navigate={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.AssessmentSettings.SettingsLive, @section_slug, :student_exceptions, @assessment_id)}>
          <%= @exceptions_count %>
        </.link>
      <% else %>
        <%= @exceptions_count %>
      <% end %>
    </div>
    """
  end
end
