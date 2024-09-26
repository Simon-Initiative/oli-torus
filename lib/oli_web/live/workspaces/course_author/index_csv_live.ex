defmodule OliWeb.Workspaces.CourseAuthor.IndexCsvLive do
  use OliWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    project = socket.assigns.project

    {:ok,
     assign(socket,
       resource_slug: project.slug,
       resource_title: project.title
     )
     |> allow_upload(:csv, accept: ~w(.csv))}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-8">
      <h3 class="display-6">CSV Import</h3>
      <p class="lead">Upload a <code>.csv</code> file to inject data into existing project.</p>
      <hr class="my-4" />

      <.form for={%{}} phx-submit="upload_csv" phx-change="validate_upload" multipart>
        <div class="form-group">
          <label>Select a CSV file</label>
          <.live_file_input upload={@uploads.csv} class="form-control" />
        </div>
        <div class="form-group">
          <div><button type="submit" class="btn btn-primary">Import</button></div>
        </div>
      </.form>

      <hr class="my-4" />

      <div>
        <.link class="btn btn-link px-0" href={~p"/admin/#{@project.slug}/import/download"}>
          Download
        </.link>
        a <code>.csv</code>
        file for this project with all pages and containers and current values for nextgen attrs
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("upload_csv", _params, socket) do
    %{current_author: author, project: project} = socket.assigns

    uploaded_files =
      consume_uploaded_entries(socket, :csv, fn %{path: path}, entry ->
        unless File.exists?("_imports") do
          File.mkdir!("_imports")
        end

        File.cp(path, "_imports/#{author.id}-import.csv")

        {:ok,
         %{
           "path" => path,
           "content_type" => entry.client_type,
           "filename" => entry.client_name
         }}
      end)

    action =
      if length(uploaded_files) > 0,
        do: {:info, "File uploaded successfully"},
        else: {:error, "A valid file must be attached"}

    {:noreply,
     socket
     |> put_flash(elem(action, 0), elem(action, 1))
     |> push_navigate(to: ~p"/workspaces/course_author/#{project.slug}/index_csv")}
  end
end
