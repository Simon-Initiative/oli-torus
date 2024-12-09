defmodule OliWeb.Admin.Ingest do
  use OliWeb, :live_view

  alias Oli.Repo
  alias Oli.Accounts.Author
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Breadcrumb
  alias Oli.Interop.Ingest
  alias OliWeb.Common.MonacoEditor
  alias OliWeb.Admin.Ingest.FAQ

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

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

  @impl Phoenix.LiveView
  def mount(_, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)

    {:ok,
     assign(socket,
       breadcrumbs: set_breadcrumbs(),
       author: author,
       uploaded_files: [],
       uploaded_content: nil,
       upload_errors: [],
       error: nil,
       title: "Ingest Project"
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
      {:noreply,
       redirect(socket,
         to: ~s"workspaces/course_author/#{project.slug}/overview"
       )}
    else
      error ->
        {:noreply, assign(socket, error: error)}
    end
  end

  defp is_invalid_json({:error, {:invalid_json, _schema, _errors, _json}}), do: true
  defp is_invalid_json(_), do: false
  defp get_schema({:error, {:invalid_json, schema, _errors, _json}}), do: schema
  defp get_errors({:error, {:invalid_json, _schema, errors, _json}}), do: errors
  defp get_json({:error, {:invalid_json, _schema, _errors, json}}), do: json
end
