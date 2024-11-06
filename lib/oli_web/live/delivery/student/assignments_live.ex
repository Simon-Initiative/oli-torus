defmodule OliWeb.Delivery.Student.AssignmentsLive do
  use OliWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_tab: :assignments)}
  end

  def render(assigns) do
    ~H"""
    Placeholder for new Assignments Live View
    """
  end
end
