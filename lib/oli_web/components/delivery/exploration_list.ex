defmodule OliWeb.Components.Delivery.ExplorationList do
  use Phoenix.LiveView

  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias OliWeb.Components.Delivery.ExplorationCard

  def mount(_params, %{"section_slug" => section_slug}, socket) do
    explorations = Resolver.get_by_purpose(section_slug, :application)

    {:ok,
     assign(socket,
       explorations: explorations
     )}
  end

  def render(assigns) do
    ~H"""
      <div class="flex flex-col gap-4">
        <%= if length(@explorations) > 0 do %>
          <%= for exploration <- @explorations do %>
            <ExplorationCard.render exploration={exploration} />
          <% end %>
        <% else %>
          <div class="bg-white dark:bg-gray-800 border-l-4 border-delivery-primary p-4" role="alert">
            <h6>There are no exploration pages available</h6>
          </div>
        <% end %>
      </div>
    """
  end
end
