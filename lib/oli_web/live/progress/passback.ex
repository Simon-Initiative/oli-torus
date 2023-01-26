defmodule OliWeb.Progress.Passback do
  use Surface.Component

  prop resource_access, :struct, required: true
  prop last_failed, :any, required: true
  prop grade_sync_result, :any, required: true
  prop click, :event, required: true

  def render(assigns) do
    ~F"""
    <div>
      {#if Oli.Delivery.Attempts.Core.ResourceAccess.last_grade_update_failed?(@resource_access) and
          !is_nil(@last_failed)}
        <div class="alert alert-warning" role="alert">
          <p>This student's most recent LMS grade update failed.  This sometimes happens due to temporary network
            problems between this system and the LMS.</p>

          <blockquote>
            {@last_failed.details}
          </blockquote>

          <p>To resolve this problem, try manually sending the grade to the LMS.</p>

          <p><strong>Note:</strong> If this problem persists, the root cause may be an LMS misconfiguration.
            In that case, contact your LMS administrator.</p>
        </div>
      {/if}

      <button class="btn btn-primary mb-4" phx-disable-with="Sending..." :on-click={@click}>Send Grade to LMS</button>
      {render_result(assigns, @grade_sync_result)}
    </div>
    """
  end

  def render_result(assigns, result) do
    case result do
      nil ->
        ""

      result ->
        ~F"""
        <div class="alert alert-info" role="alert">
          {result}
        </div>
        """
    end
  end
end
