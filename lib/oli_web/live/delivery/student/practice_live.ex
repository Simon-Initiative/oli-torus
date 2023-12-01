defmodule OliWeb.Delivery.Student.PracticeLive do
  use OliWeb, :live_view

  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias OliWeb.Components.Delivery.DeliberatePracticeCard

  def mount(_params, _session, socket) do
    section_slug = socket.assigns.section.slug
    practices = Resolver.get_by_purpose(section_slug, :deliberate_practice)

    {:ok, assign(socket, active_tab: :practice, practices: practices)}
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
      <div :if={Enum.count(@practices) == 0} class="text-center" role="alert">
        <h6>There are no practice pages available</h6>
      </div>

      <%= for practice <- @practices do %>
        <DeliberatePracticeCard.render
          practice={practice}
          section_slug={@section.slug}
          preview_mode={@preview_mode}
        />
      <% end %>
    </div>
    """
  end
end
