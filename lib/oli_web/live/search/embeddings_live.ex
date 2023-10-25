defmodule OliWeb.Search.EmbeddingsLive do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, :live_no_flash}
  use Phoenix.HTML
  import Ecto.Query, warn: false
  alias Oli.Repo
  import Phoenix.Component

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Conversation.Dialogue
  alias OliWeb.Dialogue.UserInput
  alias Oli.Conversation.Message

  def mount(
        %{"project_id" => project_slug},
        session,
        socket
      ) do

    {:ok,
     assign(socket,
       publication_id: Oli.Publishing.get_latest_published_publication_by_slug(project_slug).id,
       title: "Embeddings Playground"
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <button class="btn btn-primary" phx-click="calculate">Calculate Embeddings</button>
    </div>
    """
  end

  def handle_event("calculate", _, socket) do

    Oli.Search.Embeddings.update_all(socket.assigns.publication_id, true)

    {:noreply, assign(socket, minimized: true)}
  end

end
