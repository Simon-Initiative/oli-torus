defmodule OliWeb.Grades.LineItems do
  use OliWeb, :live_component

  def render(assigns) do

    disabled = if length(assigns.task_queue) > 0 do "disabled" else "" end

    ~L"""

    <div class="card">
      <div class="card-body">
        <h5 class="card-title"><%= dgettext("grades", "Update LMS Line Items") %></h5>

        <p class="card-text">

        <%= dgettext("grades", "While OLI automatically will create LMS gradebook line items as students complete assignments,
        in some circumstances an instructor may want to explicitly create gradebook line items or update them.") %>

        </p>

      </div>

      <div class="card-footer">
        <a class="btn btn-primary" phx-click="send_line_items" <%= disabled %>><%= dgettext("grades", "Update LMS Line Items") %></a>
      </div>
    </div>

    """
  end

end
