defmodule OliWeb.Progress.Passback do
  use OliWeb, :html

  attr(:resource_access, :map, required: true)
  attr(:last_failed, :any, required: true)
  attr(:grade_sync_result, :any, required: true)
  attr(:click, :any, required: true)

  def render(assigns) do
    ~H"""
    <div>
      <%= if Oli.Delivery.Attempts.Core.ResourceAccess.last_grade_update_failed?(@resource_access) and !is_nil(@last_failed) do %>
        <div class="alert alert-warning" role="alert">
          <p>
            This student's most recent LMS grade update failed.  This sometimes happens due to temporary network
            problems between this system and the LMS.
          </p>

          <blockquote>
            {@last_failed.details}
          </blockquote>

          <p>To resolve this problem, try manually sending the grade to the LMS.</p>

          <p>
            <strong>Note:</strong>
            If this problem persists, the root cause may be an LMS misconfiguration.
            In that case, contact your LMS administrator.
          </p>
        </div>
      <% end %>

      <button class="btn btn-primary mb-4" phx-disable-with="Sending..." phx-click={@click}>
        Send Grade to LMS
      </button>
      {render_result(assigns, @grade_sync_result)}
    </div>
    """
  end

  def render_result(assigns, result) do
    case result do
      nil ->
        ""

      result ->
        assigns = assign(assigns, :result, result)

        ~H"""
        <div class="alert alert-info" role="alert">
          {@result}
        </div>
        """
    end
  end
end
