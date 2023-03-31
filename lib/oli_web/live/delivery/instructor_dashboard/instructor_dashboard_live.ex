defmodule OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive do
  use OliWeb, :live_view
  alias Oli.Delivery.Metrics
  alias OliWeb.Components.Delivery.InstructorDashboard
  alias alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Collaboration
  use OliWeb.Common.Modal

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"active_tab" => "content"} = params, _, socket) do
    socket =
      socket
      |> assign(params: params, active_tab: String.to_existing_atom(params["active_tab"]))
      |> assign_new(:containers, fn ->
        {total_count, containers} =
          Sections.get_units_and_modules_containers(socket.assigns.section.slug)

        students_count = Sections.count_enrollments(socket.assigns.section.slug)

        container_ids = Enum.map(containers, fn c -> c.id end)

        student_progress =
          Metrics.progress_across(socket.assigns.section.id, container_ids, [], students_count)

        {total_count,
         Enum.map(containers, fn container ->
           Map.merge(container, %{progress: student_progress[container.id]})
         end)}
      end)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _, socket) do
    {:noreply,
     assign(socket, params: params, active_tab: String.to_existing_atom(params["active_tab"]))}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <InstructorDashboard.main_layout {assigns}>
      <InstructorDashboard.tabs active_tab={@active_tab} section_slug={@section_slug} preview_mode={@preview_mode} />
      <%= render_tab(assigns) %>
    </InstructorDashboard.main_layout>
    """
  end

  defp render_tab(%{active_tab: :students} = assigns) do
    ~H"""
      <.live_component
      id="students_table"
      module={OliWeb.Components.Delivery.Students}
      params={@params}
      context={@context}
      section={@section}
      />
    """
  end

  defp render_tab(%{active_tab: :content} = assigns) do
    ~H"""
      <.live_component
      id="content_table"
      module={OliWeb.Components.Delivery.Content}
      params={@params}
      section_slug={@section.slug}
      containers={@containers}
      />
    """
  end

  defp render_tab(%{active_tab: :manage} = assigns) do
    ~H"""
      <div class="container mx-auto mt-3 mb-5">
        <div class="bg-white dark:bg-gray-800 p-8 shadow">
          <%= live_render(@socket, OliWeb.Sections.OverviewView, id: "overview", session: %{"section_slug" => @section_slug}) %>
        </div>
      </div>
    """
  end

  defp render_tab(%{active_tab: :course_discussion} = assigns) do
    %{slug: revision_slug} = DeliveryResolver.root_container(assigns.section_slug)

    {:ok, collab_space_config} =
      Collaboration.get_collab_space_config_for_page_in_section(
        revision_slug,
        assigns.section_slug
      )

    assigns =
      Map.merge(
        assigns,
        %{revision_slug: revision_slug, collab_space_config: collab_space_config}
      )

    ~H"""
      <div class="container mx-auto mt-3 mb-5">
        <div class="bg-white dark:bg-gray-800 p-8 shadow">
         <%= if @collab_space_config do%>
          <%= live_render(@socket, OliWeb.CollaborationLive.CollabSpaceView, id: "course_discussion",
            session: %{
              "collab_space_config" => @collab_space_config,
              "section_slug" => @section_slug,
              "resource_slug" => @revision_slug,
              "is_instructor" => true,
              "title" => "Course Discussion"
            })
          %>
          <% else %>
              <h6>There is no collaboration space configured for this Course</h6>
          <% end %>
        </div>
      </div>
    """
  end

  defp render_tab(%{active_tab: :discussions} = assigns) do
    ~H"""
      <.live_component
        id="discussion_activity_table"
        module={OliWeb.Components.Delivery.DiscussionActivity}
        params={@params}
        section={@section}
        />
    """
  end

  defp render_tab(assigns) do
    ~H"""
      <p class="container mx-auto">Not available yet</p>
    """
  end
end
