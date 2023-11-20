defmodule OliWeb.Delivery.Student.AssignmentsLive do
  use OliWeb, :live_view

  alias Oli.Accounts.{User}
  alias Oli.Delivery.Sections

  def mount(_params, _session, socket) do
    assignments =
      case socket.assigns.ctx.user do
        %User{id: user_id} ->
          Sections.get_graded_pages(socket.assigns.section.slug, user_id)

        _ ->
          []
      end

    {:ok, assign(socket, active_tab: :assignments, assignments: assignments)}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-10 py-8">
      <h3>Assignments</h3>
    </div>
    """
  end
end
