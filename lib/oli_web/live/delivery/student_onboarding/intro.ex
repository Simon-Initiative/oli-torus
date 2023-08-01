defmodule OliWeb.Delivery.StudentOnboarding.Intro do
  use Phoenix.Component

  import OliWeb.Common.SourceImage
  import OliWeb.Delivery.StudentOnboarding.Wizard, only: [has_required_survey: 1, has_explorations: 1]

  attr :section, :map, required: true

  def render(assigns) do
    ~H"""
      <div class="flex flex-col gap-6">
        <img class="object-cover h-80 w-full" src={cover_image(@section)} />
        <h2>Welcome to <%= @section.title %>!</h2>
        <div>
          <p class="font-bold mb-0">Here's what to expect</p>
          <ul class="list-disc ml-6">
            <%= if has_required_survey(@section) do %>
              <li>A 5 minute survey to help shape learning your experience and let your instructor get to know you</li>
            <% end %>
            <%= if has_explorations(@section) do %>
              <li>Explorations will bring the course to life, showing its relevance in the real world</li>
            <% end %>
            <li>A personalized <%= @section.title %> experience based on your skillsets</li>
          </ul>
        </div>
      </div>
    """
  end
end
