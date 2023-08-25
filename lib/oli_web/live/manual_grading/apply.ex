defmodule OliWeb.ManualGrading.Apply do
  use OliWeb, :html

  attr(:disabled, :boolean, required: true)
  attr(:apply, :any, required: true)

  def render(assigns) do
    ~H"""
    <div class="d-flex justify-content-center">
      <button class="btn btn-primary" disabled={@disabled} phx-click={@apply}>
        Apply Score and Feedback
      </button>
    </div>
    """
  end
end
