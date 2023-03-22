defmodule OliWeb.Delivery.InstructorDashboard.StudentsLive do
  use OliWeb, :live_view

  alias OliWeb.Components.Delivery.InstructorDashboard

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_tab: :students)}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _, socket) do
    {:noreply, assign(socket, params: params)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
      <InstructorDashboard.main_layout {assigns}>
        <InstructorDashboard.tabs active_tab={@active_tab} section_slug={@section_slug} preview_mode={@preview_mode} />

        <.live_component
            id="students_table"
            module={OliWeb.Components.Delivery.Students}
            params={@params}
            context={@context}
            section={@section}
            />
      </InstructorDashboard.main_layout>
    """
  end
end
