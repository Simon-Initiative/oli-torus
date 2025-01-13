defmodule OliWeb.Authors.Invitations.InviteView do
  use OliWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <h3>Placeholder</h3>
    """
  end
end
