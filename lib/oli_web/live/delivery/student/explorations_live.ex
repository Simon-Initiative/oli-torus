defmodule OliWeb.Delivery.Student.ExplorationsLive do
  use OliWeb, :live_view

  import OliWeb.Components.Delivery.Layouts

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.header_with_sidebar_nav
      ctx={@ctx}
      section={@section}
      brand={@brand}
      preview_mode={@preview_mode}
      active_tab={:explorations}
    >
      <div class="container mx-auto px-10 py-8">
        <h3>Explorations</h3>
      </div>
    </.header_with_sidebar_nav>
    """
  end
end
