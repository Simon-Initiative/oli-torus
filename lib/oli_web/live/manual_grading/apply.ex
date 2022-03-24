defmodule OliWeb.ManualGrading.Apply do
  use Surface.Component

  prop disabled, :boolean, required: true
  prop apply, :event, required: true

  def render(assigns) do
    ~F"""
    <div class="d-flex justify-content-center">
      <button class="btn btn-primary" disabled={@disabled} :on-click={@apply}>Apply Score and Feedback</button>
    </div>
    """
  end

end
