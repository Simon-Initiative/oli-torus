defmodule OliWeb.Sections.AssessmentSettings.StudentExceptionsTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Sections.AssessmentSettings.Tooltips
  alias Phoenix.LiveView.JS

  use Phoenix.Component

  def new(
        student_exceptions,
        section_slug,
        selected_assessment,
        target,
        selected_student_exceptions,
        ctx,
        on_edit_date,
        on_edit_password,
        on_no_edit_password,
        edit_password_id \\ nil
      ) do
    column_specs = [
      %ColumnSpec{
        name: :student,
        label: "STUDENT",
        render_fn: &render_student_column/3,
        th_class: "pl-10 !sticky left-0 bg-white dark:bg-neutral-800 z-10",
        td_class: "sticky left-0 bg-white dark:bg-neutral-800 z-10 whitespace-nowrap"
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
        label: "SCORING",
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
        ctx: ctx,
        on_edit_date: on_edit_date,
        on_edit_password: on_edit_password,
        on_no_edit_password: on_no_edit_password,
        edit_password_id: edit_password_id
      }
    )
  end

  def render_student_column(assigns, student_exception, _) do
    assigns =
      Map.merge(assigns, %{name: student_exception.user.name, id: student_exception.user_id})

    ~H"""
    <div class="pl-1 pr-4">
      <input
        class="mr-2"
        type="checkbox"
        checked={@id in @selected_student_exceptions}
        name={"checkbox-#{@id}"}
      />
      {@name}
    </div>
    """
  end

  def render_available_date_column(assigns, student_exception, _) do
    assigns =
      Map.merge(assigns, %{
        available_date: student_exception.start_date,
        id: student_exception.user_id
      })

    ~H"""
    <div class={data_class(@selected_assessment.start_date, @available_date)}>
      <div class="relative">
        <button
          class="hover:underline whitespace-nowrap"
          type="button"
          phx-click={edit_date_and_show_modal(@on_edit_date, "available_date")}
          phx-value-user_id={@id}
        >
          <%= if is_nil(@available_date) do %>
            Always available
          <% else %>
            {value_from_datetime(@available_date, @ctx)}
          <% end %>
        </button>
      </div>
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
      <div class="relative">
        <button
          class="hover:underline whitespace-nowrap"
          type="button"
          phx-click={edit_date_and_show_modal(@on_edit_date, "due_date")}
          phx-value-user_id={@id}
        >
          <%= if @due_date do %>
            {value_from_datetime(@due_date, @ctx)}
          <% else %>
            No due date
          <% end %>
        </button>
      </div>
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
        <input
          class="w-28"
          type="number"
          min="0"
          value={@max_attempts}
          placeholder="-"
          phx-debounce={300}
          name={"max_attempts-#{@id}"}
        />
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
        <input
          class="w-28"
          type="number"
          min="0"
          value={@time_limit}
          placeholder="-"
          phx-debounce={300}
          name={"time_limit-#{@id}"}
        />
        <%= if @time_limit == 0 do %>
          <span class="text-[10px] absolute -ml-20 mt-3">(Unlimited)</span>
        <% end %>
      </div>
    </div>
    """
  end

  def render_late_policy_column(assigns, student_exception, _) do
    assigns =
      Map.merge(assigns, %{
        late_start: student_exception.late_start,
        late_submit: student_exception.late_submit,
        id: student_exception.user_id
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
      <input
        class="w-28"
        type="number"
        min="0"
        value={@grace_period}
        placeholder="-"
        phx-debounce={500}
        name={"grace_period-#{@id}"}
      />
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

  def render_assessment_mode_column(assigns, student_exception, _) do
    assigns =
      Map.merge(assigns, %{
        assessment_mode: student_exception.assessment_mode,
        id: student_exception.user_id
      })

    ~H"""
    <div class={data_class(@selected_assessment.assessment_mode, @assessment_mode)}>
      <select class="torus-select pr-32" name={"assessment_mode-#{@id}"}>
        <option disabled selected={@assessment_mode == nil} hidden value="">-</option>
        <option selected={@assessment_mode == :traditional} value={:traditional}>Traditional</option>
        <option selected={@assessment_mode == :one_at_a_time} value={:one_at_a_time}>
          One at a time
        </option>
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

  def render_password_column(assigns, student_exception, _) do
    assigns =
      Map.merge(assigns, %{
        password: student_exception.password,
        id: student_exception.user_id
      })

    ~H"""
    <div class={data_class(@selected_assessment.password, @password)}>
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
          <button type="button" phx-click={@on_edit_password} phx-value-user_id={@id}>
            <input class="w-40" type="password" value={hide_password(@password)} />
          </button>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp hide_password(password) do
    String.replace(password, ~r/./, "*")
  end

  defp data_class(assessment_data, student_exception_data)
       when assessment_data != student_exception_data and student_exception_data != nil do
    "highlight-exception"
  end

  defp data_class(_assessment_data, _student_exception_data), do: ""

  defp value_from_datetime(nil, _ctx), do: nil

  defp value_from_datetime(datetime, ctx) do
    datetime
    |> FormatDateTime.date(ctx: ctx, show_timezone: false)
  end

  defp edit_date_and_show_modal(on_edit_date, date_input_type),
    do: JS.push(on_edit_date, "open", target: "#student_#{date_input_type}_modal")
end
