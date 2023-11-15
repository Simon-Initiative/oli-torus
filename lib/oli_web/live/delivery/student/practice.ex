defmodule OliWeb.Delivery.Student.PracticeLive do
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
      active_tab={:practice}
    >
      <div class="container mx-auto px-10 mt-3 mb-5 flex flex-col">
        <%= live_render(@socket, Components.Delivery.DeliberatePracticeList,
          id: "deliberate-practice-list",
          session: %{"section_slug" => @section.slug, "preview_mode" => @preview_mode}
        ) %>
      </div>
    </.header_with_sidebar_nav>
    """
  end
end
