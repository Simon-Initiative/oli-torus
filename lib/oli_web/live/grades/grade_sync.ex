defmodule OliWeb.Grades.GradeSync do
  use OliWeb, :live_component

  def render(assigns) do
    disabled =
      if length(assigns.task_queue) > 0 or assigns.selected_page == nil do
        "disabled"
      else
        ""
      end

    ~L"""

    <div class="card">
      <div class="card-body">
        <h5 class="card-title"><%= dgettext("grades", "Synchronize LMS Grades") %></h5>

        <p class="card-text">
          <%= dgettext("grades", "If an instructor changes the maximum score for an LMS gradebook line item after students
          have submitted an attempt, it is necessary to synchronize the OLI grades for that LMS gradebook item.") %>
        </p>

        <div class="alert alert-danger" role="alert">
          <strong><%= dgettext("grades", "Warning!") %></strong>

          <%= dgettext("grades", "This operation will overwrite any grades in the LMS gradebook that
          were manually adjusted or overridden by the instructor.") %>
        </div>

        <select class="custom-select custom-select-lg mb-3">
          <%= for page <- @graded_pages do %>
            <option value="<%= page.resource_id %>" phx-click="select_page" phx-value-page="<%= page.resource_id %>"><%= page.title %></option>
          <% end %>
        </select>

      </div>

      <div class="card-footer">

        <a class="btn btn-primary" phx-click="send_grades" <%= disabled %>><%= dgettext("grades", "Synchronize LMS Grades") %></a>

      </div>
    </div>

    """
  end
end
