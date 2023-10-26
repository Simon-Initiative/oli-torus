defmodule OliWeb.Search.EmbeddingsLive do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, :live_no_flash}
  use Phoenix.HTML
  import Ecto.Query, warn: false
  alias Oli.Repo
  import Phoenix.Component
  alias OliWeb.Dialogue.UserInput
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Conversation.Dialogue
  alias OliWeb.Dialogue.UserInput
  alias Oli.Conversation.Message

  def mount(
        %{"project_id" => project_slug},
        session,
        socket
      ) do

    publication_id = Oli.Publishing.get_latest_published_publication_by_slug(project_slug).id
    Oli.Authoring.Broadcaster.Subscriber.subscribe_to_revision_embedding(publication_id)

    total = Oli.Search.Embeddings.count_revision_to_embed(publication_id)

    {:ok,
     assign(socket,
       results: [],
       changeset: UserInput.changeset(%UserInput{}, %{content: ""}),
       processing: false,
       remaining: total,
       total: total,
       failed: 0,
       publication_id: publication_id,
       title: "Embeddings Playground"
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <button class="btn btn-primary" phx-click="calculate">Calculate Embeddings</button>

      <hr/>

      <p>Total: <%= @total %></p>

      <%= if @processing do %>

        <p>Remaining: <%= @remaining %></p>
        <p>Failed: <%= @failed %></p>

        <hr/>

      <% end %>

      <%= render_input(assigns) %>
      <%= render_results(assigns) %>

    </div>
    """
  end

  def render_input(assigns) do
    ~H"""
    <.form :let={f} for={@changeset} phx-submit="update">
      <div class="relative">
        <%= textarea(f, :content,
          class:
            "resize-none ml-2 w-95 p-2 w-full rounded-md border-2 border-gray-300 focus:ring-2 focus:ring-blue-500 focus:border-transparent",
          required: true
        ) %>
        <div class="absolute inset-y-0 right-0 flex items-center">
          <button
            class="h-full rounded-md border-0 bg-transparent py-0 px-2 text-gray-500 focus:ring-2 focus:ring-inset focus:ring-blue-500 sm:text-sm"
            type="submit"
          >
            <i class="fa-solid fa-arrow-right"></i>
          </button>
        </div>
      </div>
    </.form>
    """
  end

  def render_results(assigns) do
    ~H"""
    <table>
      <tbody>
        <%= for result <- @results do %>
          <tr>
            <td><%= result.title %></td>
            <td><%= result.chunk_type %></td>
            <td><%= result.chunk_ordinal %></td>
            <td><%= result.content %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  def handle_event("update", %{"user_input" => %{"content" => content}}, socket) do

    results = Oli.Search.Embeddings.search(content)

    IO.inspect results
    {:noreply, assign(socket, results: results)}
  end

  def handle_event("calculate", _, socket) do

    Oli.Search.Embeddings.update_all(socket.assigns.publication_id, false)
    {:noreply, assign(socket, processing: true)}
  end

  def handle_info({:revision_embedding_complete, result}, socket) do

    {failed, total, remaining} = case result do
      :ok -> {socket.assigns.failed, socket.assigns.total, socket.assigns.remaining - 1}
      _ -> {socket.assigns.failed + 1, socket.assigns.total + 1, socket.assigns.remaining}
    end

    processing = remaining > 0

    {:noreply, assign(socket, remaining: remaining, failed: failed, total: total, processing: processing)}
  end
end
