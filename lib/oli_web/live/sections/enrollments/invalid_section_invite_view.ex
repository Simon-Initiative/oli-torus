defmodule OliWeb.Sections.InvalidSectionInviteView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  def mount(_, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~F"""
    <div>
      This section invitation link has expired or is invalid.
    </div>
    """
  end
end
