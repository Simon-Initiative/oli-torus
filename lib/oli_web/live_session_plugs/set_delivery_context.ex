defmodule OliWeb.LiveSessionPlugs.SetDeliveryContext do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]

  alias Oli.Accounts.{User, Author}
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.DeliveryContext

  def on_mount(_, :not_mounted_at_router, _session, socket) do
    {:cont, socket}
  end

  def on_mount(:author_preview, _params, _session, %{assigns: assigns} = socket) do
    with %Author{} = author <- assigns.current_author do
      {:cont, assign(socket, delivery_context: DeliveryContext.for_author_preview(author))}
    else
      _ -> {:halt, socket}
    end
  end

  def on_mount(:learner, _params, _session, %{assigns: assigns} = socket) do
    with %User{} = user <- assigns.current_user,
         %Section{slug: section_slug} <- assigns.section do
      {:cont, assign(socket, delivery_context: DeliveryContext.for_learner(user, section_slug))}
    else
      _ -> {:halt, socket}
    end
  end
end
