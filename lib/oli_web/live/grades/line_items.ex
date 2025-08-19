defmodule OliWeb.Grades.LineItems do
  use OliWeb, :html

  attr(:task_queue, :list)
  attr(:job_status, :map, default: nil)
  attr(:section_slug, :string)

  def render(assigns) do
    assigns =
      assign(
        assigns,
        :disabled,
        if length(assigns.task_queue) > 0 or is_running?(assigns.job_status) do
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
            "Update Line Items adds all gradable items and progress containers to the LMS gradebook in course order. Otherwise, each gradable item is added to the gradebook when the first student completes it."
          )}
        </p>

        <%= if @job_status do %>
          <div class="mt-3">
            <.render_job_status job_status={@job_status} />
          </div>
        <% end %>
      </div>

      <div class="card-footer mt-4">
        <a class="btn btn-primary" phx-click="send_line_items" {@disabled}>
          {dgettext("grades", "Create All Line Items")}
        </a>
      </div>
    </div>
    """
  end

  defp render_job_status(assigns) do
    ~H"""
    <div class="alert alert-info">
      <h6 class="alert-heading">
        <%= case @job_status.status do %>
          <% :running -> %>
            <i class="fas fa-spinner fa-spin"></i> Creating Line Items...
          <% :completed -> %>
            <i class="fas fa-check-circle text-success"></i> Line Items Created Successfully
          <% :failed -> %>
            <i class="fas fa-exclamation-circle text-danger"></i> Line Item Creation Failed
          <% :cancelled -> %>
            <i class="fas fa-ban text-warning"></i> Line Item Creation Cancelled
          <% _ -> %>
            Processing...
        <% end %>
      </h6>

      <%= if @job_status.progress do %>
        <div class="mt-2">
          <div class="d-flex justify-content-between mb-1">
            <small>Progress: {@job_status.progress.processed} / {@job_status.progress.total}</small>
            <%= if @job_status.progress.failed > 0 do %>
              <small class="text-danger">Failed: {@job_status.progress.failed}</small>
            <% end %>
          </div>

          <%= if @job_status.progress.total > 0 do %>
            <div class="progress" style="height: 25px;">
              <div
                class="progress-bar bg-success"
                role="progressbar"
                style={"width: #{(@job_status.progress.processed - @job_status.progress.failed) / @job_status.progress.total * 100}%"}
                aria-valuenow={"#{@job_status.progress.processed - @job_status.progress.failed}"}
                aria-valuemin="0"
                aria-valuemax={"#{@job_status.progress.total}"}
              >
                {round(
                  (@job_status.progress.processed - @job_status.progress.failed) /
                    @job_status.progress.total * 100
                )}%
              </div>
              <%= if @job_status.progress.failed > 0 do %>
                <div
                  class="progress-bar bg-danger"
                  role="progressbar"
                  style={"width: #{@job_status.progress.failed / @job_status.progress.total * 100}%"}
                  aria-valuenow={"#{@job_status.progress.failed}"}
                  aria-valuemin="0"
                  aria-valuemax={"#{@job_status.progress.total}"}
                >
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if @job_status.errors && length(@job_status.errors) > 0 do %>
        <div class="mt-2">
          <h6 class="text-danger">Errors:</h6>
          <ul class="mb-0 small">
            <%= for error <- Enum.take(@job_status.errors, 5) do %>
              <li>{error}</li>
            <% end %>
            <%= if length(@job_status.errors) > 5 do %>
              <li><em>...and {length(@job_status.errors) - 5} more errors</em></li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <%= if @job_status.status == :completed && @job_status.progress.failed == 0 do %>
        <div class="mt-2 text-success">
          <strong>All line items have been successfully created or updated!</strong>
        </div>
      <% end %>
    </div>
    """
  end

  defp is_running?(nil), do: false
  defp is_running?(%{status: :running}), do: true
  defp is_running?(_), do: false
end
