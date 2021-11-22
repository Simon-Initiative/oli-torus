defmodule OliWeb.Progress.Passback do
  use Surface.Component
  prop grade_sync_result, :any, required: true
  prop click, :event, required: true

  def render(assigns) do
    ~F"""
    <div>
      <button class="btn btn-primary mb-4" phx-disable-with="Sending..." :on-click={@click}>Send Grade to LMS</button>
      {render_result(assigns, @grade_sync_result)}
    </div>
    """
  end

  def render_result(assigns, result) do
    case result do
      nil ->
        ""

      {:ok, :synced} ->
        ~F"""
        <div class="alert alert-success" role="alert">
          Grade successfully sent to the LMS.
        </div>
        """

      {:ok, :not_synced} ->
        ~F"""
        <div class="alert alert-info" role="alert">
          Grade passback is not enabled.
        </div>
        """

      {:error, e} ->
        ~F"""
        <div class="alert alert-danger" role="alert">
          <p>The following error was encountered:</p>

          <hr>
          <p class="mb-0">{e}</p>
        </div>
        """
    end
  end
end
