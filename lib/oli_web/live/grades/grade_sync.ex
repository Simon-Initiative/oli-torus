defmodule OliWeb.Grades.GradeSync do
  use OliWeb, :html

  attr(:task_queue, :list)
  attr(:total_jobs, :list)
  attr(:failed_jobs, :list)
  attr(:succeeded_jobs, :list)
  attr(:graded_pages, :list)
  attr(:selected_page, :map)

  def render(assigns) do
    assigns =
      assign(
        assigns,
        :disabled,
        if length(assigns.task_queue) > 0 or assigns.selected_page == nil do
          [disabled: true]
        else
          []
        end
      )

    ~H"""
    <div class="card">
      <div class="card-body">
        <h5 class="card-title"><%= dgettext("grades", "Synchronize Grades") %></h5>

        <p class="card-text">
          <%= dgettext(
            "grades",
            "If an instructor changes the maximum score for an LMS gradebook line item after students
          have submitted an attempt, it is necessary to synchronize the grades for that LMS gradebook item."
          ) %>
        </p>

        <div class="alert alert-danger" role="alert">
          <strong><%= dgettext("grades", "Warning!") %></strong>

          <%= dgettext("grades", "This operation will overwrite any grades in the LMS gradebook that
          were manually adjusted or overridden by the instructor.") %>
        </div>

        <form id="grade_sync_form" />
        <select
          phx-change="select_page"
          id="assignment_grade_sync_select"
          name="resource_id"
          class="custom-select custom-select-lg mb-2"
          form="grade_sync_form"
        >
          <%= for page <- @graded_pages do %>
            <option value={page.resource_id} selected={@selected_page == page.resource_id}>
              <%= page.title %>
            </option>
          <% end %>
        </select>

        <%= if !is_nil(assigns.total_jobs) do %>
          <p>
            Pending grade updates: <%= assigns.total_jobs -
              (assigns.failed_jobs + assigns.succeeded_jobs) %>
          </p>
          <p>Succeeded: <%= assigns.succeeded_jobs %></p>
          <p>Failed: <%= assigns.failed_jobs %></p>
        <% end %>
      </div>

      <div class="card-footer mt-4">
        <a class="btn btn-primary" phx-click="send_grades" {@disabled}>
          <%= dgettext("grades", "Synchronize Grades") %>
        </a>
      </div>
    </div>
    """
  end
end
