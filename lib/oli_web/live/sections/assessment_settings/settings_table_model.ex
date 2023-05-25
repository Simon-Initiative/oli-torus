defmodule OliWeb.Sections.AssessmentSettings.SettingsTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.FormatDateTime
  use Phoenix.Component

  def new(assessments, section_slug, context) do
    column_specs = [
      %ColumnSpec{
        name: :assessment,
        label: "ASSESSMENT",
        render_fn: &__MODULE__.render_assessment_column/3,
        th_class: "pl-10 instructor_dashboard_th sticky left-0 bg-white z-10",
        td_class: "sticky left-0 bg-white z-10 whitespace-nowrap"
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
        section_slug: section_slug,
        context: context
      }
    )
  end

  def render_assessment_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{assessment: assessment.name})

    ~H"""
      <div class="pl-9 pr-4"><%= @assessment %></div>
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
      <%= if @scheduling_type == :due_by do %>
        <input name={"end_date-#{@id}"} type="datetime-local" phx-debounce={500} value={value_from_datetime(@due_date, @context)}/>
      <% else %>
        No due date
      <% end %>
    """
  end

  def render_attempts_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{attempts: assessment.max_attempts, id: assessment.resource_id})

    ~H"""
      <div class="relative">
        <input class="mr-3 w-28" type="number" min="0" value={@attempts} phx-debounce={300} name={"max_attempts-#{@id}"} />
        <%= if @attempts == 0 do %>
          <span class="text-[10px] absolute -ml-24 mt-3">(Unlimited)</span>
        <% end %>
      </div>
    """
  end

  def render_time_limit_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{time_limit: assessment.time_limit, id: assessment.resource_id})

    ~H"""
      <div class="relative">
        <input class="mr-3 w-28" type="number" min="0" value={@time_limit} phx-debounce={300} name={"time_limit-#{@id}"} />
        <%= if @time_limit == 0 do %>
          <span class="text-[10px] absolute -ml-24 mt-3">(Unlimited)</span>
        <% end %>
      </div>
    """
  end

  def render_late_submit_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{late_submit: assessment.late_submit, id: assessment.resource_id})

    ~H"""
      <select class="torus-select pr-32" name={"late_submit-#{@id}"}>
        <option selected={@late_submit == :allow} value={:allow}>Allow</option>
        <option selected={@late_submit == :disallow} value={:disallow}>Disallow</option>
      </select>
    """
  end

  def render_late_start_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{late_start: assessment.late_start, id: assessment.resource_id})

    ~H"""
      <select class="torus-select pr-32" name={"late_start-#{@id}"}>
        <option selected={@late_start == :allow} value={:allow}>Allow</option>
        <option selected={@late_start == :disallow} value={:disallow}>Disallow</option>
      </select>
    """
  end

  def render_scoring_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{scoring: assessment.scoring_strategy_id, id: assessment.resource_id})

    ~H"""
      <select class="torus-select pr-32" name={"scoring_strategy_id-#{@id}"}>
        <option selected={@scoring == 1} value={1}>Average</option>
        <option selected={@scoring == 2} value={2}>Best</option>
        <option selected={@scoring == 3} value={3}>Last</option>
      </select>
    """
  end

  def render_grace_period_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{grace_period: assessment.grace_period, id: assessment.resource_id})

    ~H"""
      <input class="w-28" type="number" min="0" value={@grace_period} phx-debounce={500} name={"grace_period-#{@id}"} />
    """
  end

  def render_retake_mode_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{retake_mode: assessment.retake_mode, id: assessment.resource_id})

    ~H"""
      <select class="torus-select pr-32" name={"retake_mode-#{@id}"}>
        <option selected={@retake_mode == :targeted} value={:targeted}>Targeted</option>
        <option selected={@retake_mode == :normal} value={:normal}>Normal</option>
      </select>
    """
  end

  def render_view_feedback_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{view_feedback: assessment.feedback_mode, id: assessment.resource_id})

    ~H"""
      <select class="torus-select pr-32" name={"feedback_mode-#{@id}"}>
        <option selected={@view_feedback == :allow} value={:allow}>Allow</option>
        <option selected={@view_feedback == :disallow} value={:disallow}>Disallow</option>
        <option selected={@view_feedback == :scheduled} value={:scheduled}>Scheduled</option>
      </select>
    """
  end

  def render_view_answers_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        view_answers: assessment.review_submission,
        id: assessment.resource_id
      })

    ~H"""
      <select class="torus-select pr-32" name={"review_submission-#{@id}"}>
        <option selected={@view_answers == :allow} value={:allow}>Allow</option>
        <option selected={@view_answers == :disallow} value={:disallow}>Disallow</option>
      </select>
    """
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
        class="ml-6 text-gray-600 underline hover:text-gray-700"
        navigate={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.AssessmentSettings.SettingsLive, @section_slug, :student_exceptions, @id)}>
        <%= @exceptions_count %>
      </.link>
    </div>
    """
  end

  defp value_from_datetime(nil, _context), do: nil

  defp value_from_datetime(datetime, context) do
    datetime
    |> FormatDateTime.convert_datetime(context)
    |> DateTime.to_iso8601()
    |> String.slice(0, 16)
  end
end
