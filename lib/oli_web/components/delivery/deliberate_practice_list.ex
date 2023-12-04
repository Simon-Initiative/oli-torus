defmodule OliWeb.Components.Delivery.DeliberatePracticeList do
  use Phoenix.LiveView

  alias Oli.Publishing.DeliveryResolver, as: Resolver
  alias OliWeb.Components.Delivery.DeliberatePracticeCard

  def mount(_params, %{"section_slug" => section_slug, "preview_mode" => preview_mode}, socket) do
    practices = Resolver.get_by_purpose(section_slug, :deliberate_practice)

    {:ok,
     assign(socket,
       practices: practices,
       section_slug: section_slug,
       preview_mode: preview_mode
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-4">
      <%= if length(@practices) > 0 do %>
        <%= for practice <- @practices do %>
          <DeliberatePracticeCard.render
            practice={practice}
            section_slug={@section_slug}
            preview_mode={@preview_mode}
          />
        <% end %>
      <% else %>
        <div class="bg-white dark:bg-gray-800 border-l-4 border-delivery-primary p-4" role="alert">
          <h6>There are no deliberate practice pages available</h6>
        </div>
      <% end %>
    </div>
    """
  end
end
