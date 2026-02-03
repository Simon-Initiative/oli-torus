defmodule OliWeb.Delivery.Surveys.SurveysAssessmentsTableModel do
  use Phoenix.Component

  import OliWeb.Components.Common
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS
  alias OliWeb.Delivery.ActivityHelpers

  def new(assessments, target, students, activity_types_map) do
    column_specs = [
      %ColumnSpec{
        render_fn: &render_expanded/3,
        sortable: false,
        th_class: "w-4"
      },
      %ColumnSpec{
        name: :title,
        label: "Survey Name",
        render_fn: &__MODULE__.render_assessment_column/3,
        th_class: "pl-10"
      }
    ]

    SortableTableModel.new(
      rows: assessments,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:resource_id],
      data: %{
        expandable_rows: true,
        view_type: :surveys_instructor_dashboard,
        target: target,
        students: students,
        activity_types_map: activity_types_map
      }
    )
  end

  def render_expanded(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        id: "#{assessment.resource_id}",
        target: assigns.model.data.target,
        assessment: assessment
      })

    ~H"""
    <.button
      id={"button_#{@id}"}
      class="flex !p-0"
      phx-click={
        JS.push("paged_table_selection_change",
          value: %{id: @assessment.resource_id},
          target: @target
        )
        |> JS.toggle(to: "#details-row_#{@id}")
        |> JS.toggle_class("rotate-180", to: "#button_#{@id} svg")
        |> JS.toggle_class("bg-Table-table-select", to: ~s(tr[data-row-id="row_#{@id}"]))
      }
    >
      <Icons.chevron_down class="fill-Text-text-high transition-transform duration-200" />
    </.button>
    """
  end

  def render_survey_details(assigns, survey) do
    selected_survey_ids = get_in(assigns.model.data, [:selected_survey_ids]) || []
    survey_activities_map = get_in(assigns.model.data, [:survey_activities_map]) || %{}

    activity_types_map =
      get_in(assigns.model.data, [:activity_types_map]) || assigns[:activity_types_map]

    students = get_in(assigns.model.data, [:students]) || []

    activities = Map.get(survey_activities_map, survey.resource_id, [])
    should_show_details = survey.resource_id in selected_survey_ids and is_list(activities)

    assigns =
      Map.merge(assigns, %{
        activities: activities,
        activity_types_map: activity_types_map,
        students: students,
        should_show_details: should_show_details
      })

    ~H"""
    <%= if @should_show_details do %>
      <%= if @activities == [] do %>
        <div class="px-10 py-6 text-sm text-Text-text-muted dark:text-Text-text-muted">
          No attempts have been recorded for this survey yet.
        </div>
      <% else %>
        <div :for={activity <- @activities} class="px-10">
          <div class="flex flex-col bg-white dark:bg-gray-800 dark:text-white w-full whitespace-nowrap rounded-t-md font-medium text-sm leading-tight uppercase border-x-1 border-t-1 border-b-0 border-gray-300 px-6 py-4 my-4 gap-y-2">
            <div role="activity_title">{activity.title} - Question details</div>
            <div
              id={"student_attempts_summary_#{activity.id}"}
              class="flex flex-row items-center gap-x-2 lowercase w-full h-6"
            >
              <span class="text-xs">
                <%= if activity.students_with_attempts_count == 0 do %>
                  No student has completed any attempts.
                <% else %>
                  {~s{#{activity.students_with_attempts_count} #{Gettext.ngettext(OliWeb.Gettext, "student has", "students have", activity.students_with_attempts_count)} completed #{activity.total_attempts_count} #{Gettext.ngettext(OliWeb.Gettext, "attempt", "attempts", activity.total_attempts_count)}.}}
                <% end %>
              </span>
              <div
                :if={
                  activity.students_with_attempts_count <
                    (Map.get(activity, :students_count) || Enum.count(@students))
                }
                class="flex gap-x-2 items-center w-full"
              >
                <span class="text-xs">
                  {~s{#{Map.get(activity, :emails_without_attempts_count) || Enum.count(activity.student_emails_without_attempts || [])} #{Gettext.ngettext(OliWeb.Gettext,
                  "student has",
                  "students have",
                  Map.get(activity, :emails_without_attempts_count) || Enum.count(activity.student_emails_without_attempts || []))} not completed any attempt.}}
                </span>
                <input
                  type="text"
                  id={"email_inputs_#{activity.id}"}
                  class="form-control hidden"
                  value={Enum.join(activity.student_emails_without_attempts, "; ")}
                  readonly
                />
                <button
                  id={"copy_emails_button_#{activity.id}"}
                  class="flex items-center gap-x-1.5 text-xs text-Text-text-button ml-auto"
                  phx-hook="CopyListener"
                  data-clipboard-target={"#email_inputs_#{activity.id}"}
                >
                  <Icons.email /> <span>Email</span>
                </button>
              </div>
            </div>
          </div>
          <div
            class="bg-white dark:bg-gray-800 dark:text-white shadow-sm px-6 -mt-5"
            id={"activity_detail_#{activity.id}"}
            phx-hook="LoadSurveyScripts"
            phx-update="ignore"
          >
            <%= if Map.get(activity, :preview_rendered) != nil do %>
              <ActivityHelpers.rendered_activity
                activity={activity}
                activity_types_map={@activity_types_map}
              />
            <% else %>
              <p class="pt-9 pb-5">No attempt registered for this question</p>
            <% end %>
          </div>
        </div>
      <% end %>
    <% else %>
      <div class="p-6 flex justify-center items-center">
        <span
          class="spinner-border spinner-border-sm h-8 w-8 text-Text-text-button"
          role="status"
          aria-hidden="true"
        >
        </span>
      </div>
    <% end %>
    """
  end

  def render_assessment_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        title: assessment.title,
        id: assessment.id
      })

    ~H"""
    <div class="pr-4 flex flex-col">
      <span>
        {@title}
      </span>
    </div>
    """
  end
end
