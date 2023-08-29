defmodule OliWeb.Sections.InvalidSectionInviteView do
  use OliWeb, :live_view

  def mount(_, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      This section invitation link has expired or is invalid.
    </div>
    """
  end
end
