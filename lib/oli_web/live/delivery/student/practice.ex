defmodule OliWeb.Delivery.Student.PracticeLive do
  use OliWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_tab: :practice)}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-10 mt-3 mb-5 flex flex-col">
      <%= live_render(@socket, Components.Delivery.DeliberatePracticeList,
        id: "deliberate-practice-list",
        session: %{"section_slug" => @section.slug, "preview_mode" => @preview_mode}
      ) %>
    </div>
    """
  end
end
