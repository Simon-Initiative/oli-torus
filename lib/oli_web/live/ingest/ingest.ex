defmodule OliWeb.Admin.Ingest do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Repo
  alias Oli.Accounts.Author
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Breadcrumb
  alias Oli.Interop.Ingest
  alias OliWeb.Common.MonacoEditor
  alias OliWeb.Admin.Ingest.FAQ

  prop author, :any
  data breadcrumbs, :any
  data title, :string, default: "Ingest Project"

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb()
    |> breadcrumb()
  end

  def breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Ingest Project",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
        })
      ]
  end

  def mount(_, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)

    {:ok,
     assign(socket,
       breadcrumbs: set_breadcrumbs(),
       author: author,
       uploaded_files: [],
       uploaded_content: nil,
       upload_errors: [],
       error: nil
     )
     |> allow_upload(:digest, accept: ~w(.zip), max_entries: 1)}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :digest, ref)}
  end

  @impl Phoenix.LiveView
  def handle_event("ingest", _params, socket) do
    socket = clear_flash(socket)
    %{author: author} = socket.assigns

    with path_upload <-
           consume_uploaded_entries(socket, :digest, fn %{path: path}, _entry -> {:ok, path} end),
         {:ok, project} <-
           Ingest.ingest(
             List.first(path_upload),
             author
           ) do
      {:noreply, redirect(socket, to: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.OverviewLive, project.slug))}
    else
      error ->
        {:noreply, assign(socket, error: error)}
    end
  end
end
