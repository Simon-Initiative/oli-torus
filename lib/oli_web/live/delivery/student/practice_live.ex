defmodule OliWeb.Delivery.Student.PracticeLive do
  use OliWeb, :live_view

  alias Oli.Delivery.Sections
  alias OliWeb.Components.Delivery.DeliberatePractice

  def mount(_params, _session, socket) do
    practices_by_container =
      Sections.get_practice_pages_by_containers(socket.assigns.section)

    {:ok, assign(socket, active_tab: :practice, practices_by_container: practices_by_container)}
  end

  def render(assigns) do
    ~H"""
    <div class="w-full bg-cover bg-center bg-no-repeat bg-gray-700 text-white py-24 px-16">
      <div class="container mx-auto flex flex-col lg:flex-row">
        <div class="lg:flex-1">
          <h1 class="text-4xl mb-8">Your Practice Pages</h1>
        </div>
      </div>
    </div>
    <div class="container mx-auto flex flex-col mt-6 px-16">
      <div :if={Enum.count(@practices_by_container) == 0} class="text-center" role="alert">
        <h6>There are no practice pages available</h6>
      </div>

      <%= for {container_name, practices} <- @practices_by_container do %>
        <h2 :if={container_name != :default} class="text-sm font-bold my-6 uppercase text-gray-700">
          <%= container_name %>
        </h2>

        <DeliberatePractice.practice_card
          :for={practice <- practices}
          practice={practice}
          section_slug={@section.slug}
          preview_mode={@preview_mode}
        />
      <% end %>
    </div>
    """
  end
end
