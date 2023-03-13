defmodule OliWeb.Components.Delivery.AssignmentsList do
  use Phoenix.LiveView

  alias OliWeb.Components.Delivery.AssignmentCard

  def render(assigns) do
    ~H"""
    <div class="px-10 py-11">
      <h3>Assignments</h3>
      <p>Find all your assignments, quizzes and activities associated with graded material.</p>
      <div class="flex flex-col gap-2 mt-6">
        <AssignmentCard.render />
      </div>
    </div>
    """
  end
end
