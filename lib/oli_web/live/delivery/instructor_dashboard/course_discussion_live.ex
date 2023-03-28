defmodule OliWeb.Delivery.InstructorDashboard.CourseDiscussionLive do
  use OliWeb, :live_view

  alias OliWeb.Components.Delivery.InstructorDashboard
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Collaboration

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    %{slug: revision_slug} = DeliveryResolver.root_container(socket.assigns.section_slug)

    {:ok, collab_space_config} =
      Collaboration.get_collab_space_config_for_page_in_section(
        revision_slug,
        socket.assigns.section_slug
      )

    {:ok,
     assign(socket, %{revision_slug: revision_slug, collab_space_config: collab_space_config})}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
      <InstructorDashboard.course_discussion {assigns} />
    """
  end
end
