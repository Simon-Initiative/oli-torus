defmodule OliWeb.Components.Delivery.AssignmentsList do
  use Phoenix.LiveComponent

  alias OliWeb.Components.Delivery.AssignmentCard

  def render(assigns) do
    ~H"""
    <div class="px-10 py-11">
      <h3>Assignments</h3>
      <p>Find all your assignments, quizzes and activities associated with graded material.</p>
      <div class="flex flex-col gap-4 mt-6">
      <%= for assignment <- @assignments do %>
        <AssignmentCard.render assignment={assignment} section_slug={@section_slug}/>
      <% end %>
      </div>
    </div>
    """
  end
end
