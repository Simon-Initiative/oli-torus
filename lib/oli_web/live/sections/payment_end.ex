defmodule OliWeb.Sections.PaymentEnd do
  use Surface.LiveView

  alias OliWeb.Router.Helpers, as: Routes
  alias Phoenix.PubSub

  data topic, :string, default: "section:payment"

  def mount(
        _params,
        %{
          "section" => section,
          "user" => user
        } = _session,
        socket
      ) do

    PubSub.subscribe(Oli.PubSub, "section:payment:" <> Integer.to_string(user.id))

    {:ok, assign(socket,
      section: section,
      user: user
    )}
  end

  def render(assigns) do
    ~F"""
    <div></div>
    """
  end

  def handle_info({:payment, _payload}, socket) do
    %{section: section} = socket.assigns
    {:noreply, push_redirect(socket, to: Routes.page_delivery_path(OliWeb.Endpoint, :index, section.slug))}
  end

end
