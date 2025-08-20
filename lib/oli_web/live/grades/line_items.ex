defmodule OliWeb.Grades.LineItems do
  use OliWeb, :html

  attr(:task_queue, :list)

  def render(assigns) do
    assigns =
      assign(
        assigns,
        :disabled,
        if length(assigns.task_queue) > 0 do
          [disabled: true]
        else
          []
        end
      )

    ~H"""
    <div class="card">
      <div class="card-body">
        <h5 class="card-title">{dgettext("grades", "Update Line Items")}</h5>

        <p class="card-text">
          {dgettext(
            "grades",
            "Update Line Items adds all gradable items to the LMS gradebook. Otherwise, each gradable item is added to the gradebook when the first student completes it."
          )}
        </p>
      </div>

      <div class="card-footer mt-4">
        <a class="btn btn-primary" phx-click="send_line_items" {@disabled}>
          {dgettext("grades", "Update LMS Line Items")}
        </a>
      </div>
    </div>
    """
  end
end
