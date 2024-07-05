defmodule OliWeb.Sections.InvalidSectionInviteView do
  use OliWeb, :live_view

  def mount(_, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="p-10">
      This enrollment link has expired or is invalid. If you already have a Torus student account, please <a href="/session/new">sign in</a>.
    </div>
    """
  end
end
