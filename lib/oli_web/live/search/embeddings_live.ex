defmodule OliWeb.Search.EmbeddingsLive do
  use Phoenix.LiveView, layout: {OliWeb.LayoutView, :live_no_flash}
  use Phoenix.HTML
  import Ecto.Query, warn: false
  import Phoenix.Component
  alias OliWeb.Dialogue.UserInput
  alias OliWeb.Dialogue.UserInput

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}

  def mount(
        %{"project_id" => project_slug},
        _session,
        socket
      ) do
    publication_id = Oli.Publishing.get_latest_published_publication_by_slug(project_slug).id
    Oli.Authoring.Broadcaster.Subscriber.subscribe_to_revision_embedding(publication_id)

    %{
      total_embedded: total_embedded,
      total_revisions_embedded: total_revisions_embedded,
      total_to_embed: total_to_embed
    } = Oli.Search.Embeddings.project_embeddings_summary(publication_id)

    {:ok,
     assign(socket,
       results: [],
       changeset: UserInput.changeset(%UserInput{}, %{content: ""}),
       processing: false,
       remaining: total_to_embed,
       total_to_embed: total_to_embed,
       total: total_revisions_embedded,
       total_embedded: total_embedded,
       failed: 0,
       publication_id: publication_id,
       title: "Embeddings Playground"
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h3>Revision Embedding Status</h3>

      <p>{@total} pages embedded across {@total_embedded} chunks</p>
      <p>{@total_to_embed} pages need to be embedded</p>

      <%= if @processing do %>
        <p>Remaining: {@remaining}</p>
        <p>Failed: {@failed}</p>
      <% end %>

      <button class="btn btn-primary" phx-click="calculate">Calculate Embeddings</button>

      <hr class="mt-5 mb-5" />

      <h3>Semantic Search</h3>
      <p><small class="text-muted">Enter some text and see what chunks are returned</small></p>

      {render_input(assigns)}
      {render_results(assigns)}
    </div>
    """
  end

  def render_input(assigns) do
    ~H"""
    <.form :let={f} for={@changeset} phx-submit="update">
      <div class="relative">
        {textarea(f, :content,
          class:
            "resize-none ml-2 w-95 p-2 w-full rounded-md border-2 border-gray-300 focus:ring-2 focus:ring-blue-500 focus:border-transparent",
          required: true
        )}
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
            <td>{result.title}</td>
            <td>{result.chunk_type}</td>
            <td>{result.chunk_ordinal}</td>
            <td>{result.distance}</td>
            <td>{result.content}</td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  def handle_event("update", %{"user_input" => %{"content" => content}}, socket) do
    results = Oli.Search.Embeddings.search(content, socket.assigns.publication_id)

    {:noreply, assign(socket, results: results)}
  end

  def handle_event("calculate", _, socket) do
    Oli.Search.Embeddings.update_all(socket.assigns.publication_id, false)
    {:noreply, assign(socket, processing: true)}
  end

  def handle_info({:revision_embedding_complete, result}, socket) do
    {failed, total, remaining} =
      case result do
        :ok -> {socket.assigns.failed, socket.assigns.total, socket.assigns.remaining - 1}
        _ -> {socket.assigns.failed + 1, socket.assigns.total + 1, socket.assigns.remaining}
      end

    processing = remaining > 0

    {:noreply,
     assign(socket, remaining: remaining, failed: failed, total: total, processing: processing)}
  end
end
