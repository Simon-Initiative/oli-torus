defmodule OliWeb.Delivery.Student.DiscussionLive do
  use OliWeb, :live_view

  def mount(
        _params,
        _session,
        socket
      ) do
    {:ok, assign(socket, active_tab: :discussion)}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-10 py-8">
      <h3>Discussion Board</h3>
    </div>
    """
  end
end
