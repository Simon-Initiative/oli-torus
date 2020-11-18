defmodule OliWeb.Grades.GradeSync do
  use Phoenix.LiveComponent

  def render(assigns) do

    disabled = if length(assigns.task_queue) > 0 do "disabled" else "" end

    ~L"""

    <div class="card">
      <div class="card-body">
        <h5 class="card-title">Synchronize LMS Grades</h5>

        <p class="card-text">
        If an instructor changes the maximum score for an LMS gradebook line item <b>after</b> students
        have submitted an attempt, it is necessary to synchronize the OLI grades and the LMS gradebook.</p>

      </div>

      <div class="card-footer">

        <a class="btn btn-primary" phx-click="send_grades" <%= disabled %>>Synchronize LMS Grades</a>

      </div>
    </div>

    """
  end

end
