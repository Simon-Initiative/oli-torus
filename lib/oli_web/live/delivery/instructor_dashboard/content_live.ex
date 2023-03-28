defmodule OliWeb.Delivery.InstructorDashboard.ContentLive do
  use OliWeb, :live_view

  alias OliWeb.Router.Helpers, as: Routes
  alias alias Oli.Delivery.Sections
  alias OliWeb.Components.Delivery.InstructorDashboard

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    page_link_url =
      if socket.assigns.preview_mode do
        &Routes.page_delivery_path(
          OliWeb.Endpoint,
          :page_preview,
          socket.assigns.section_slug,
          &1
        )
      else
        &Routes.page_delivery_path(OliWeb.Endpoint, :page, socket.assigns.section_slug, &1)
      end

    container_link_url =
      if socket.assigns.preview_mode do
        &Routes.page_delivery_path(
          OliWeb.Endpoint,
          :container_preview,
          socket.assigns.section_slug,
          &1
        )
      else
        &Routes.page_delivery_path(OliWeb.Endpoint, :container, socket.assigns.section_slug, &1)
      end

    {:ok,
     assign(socket,
       hierarchy: Sections.build_hierarchy(socket.assigns.section),
       display_curriculum_item_numbering:
         socket.assigns.section.display_curriculum_item_numbering,
       page_link_url: page_link_url,
       container_link_url: container_link_url
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
      <InstructorDashboard.content {assigns} />
    """
  end
end
