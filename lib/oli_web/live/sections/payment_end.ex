defmodule OliWeb.Sections.PaymentEnd do
  use OliWeb, :live_view

  alias OliWeb.Router.Helpers, as: Routes
  alias Phoenix.PubSub

  def mount(
        _params,
        %{
          "section" => section,
          "user" => user
        } = _session,
        socket
      ) do
    PubSub.subscribe(Oli.PubSub, "section:payment:" <> Integer.to_string(user.id))

    {:ok,
     assign(socket,
       section: section,
       user: user
     )}
  end

  attr :topic, :string, default: "section:payment"

  def render(assigns) do
    ~H"""
    <div />
    """
  end

  def handle_info({:payment, _payload}, socket) do
    %{section: section} = socket.assigns

    {:noreply,
     push_redirect(socket, to: Routes.page_delivery_path(OliWeb.Endpoint, :index, section.slug))}
  end
end
