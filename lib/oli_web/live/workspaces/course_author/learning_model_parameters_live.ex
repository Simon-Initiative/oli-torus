defmodule OliWeb.Workspaces.CourseAuthor.LearningModelParametersLive do
  @moduledoc "Admin workspace for downloading and applying project learning-model parameters."

  use OliWeb, :live_view

  require Logger

  alias Oli.LearningModel.ParameterCsv
  alias OliWeb.Common.Breadcrumb

  @impl true
  def mount(_params, _session, socket) do
    %{project: project, current_author: author} = socket.assigns

    case ParameterCsv.authorize(project, author) do
      :ok ->
        {:ok,
         socket
         |> assign(
           resource_slug: project.slug,
           resource_title: project.title,
           page_title: "Learning Model Parameters",
           importing?: false,
           breadcrumbs: [
             Breadcrumb.new(%{
               full_title: "Project Overview",
               link: ~p"/workspaces/course_author/#{project.slug}/overview"
             }),
             Breadcrumb.new(%{full_title: "Learning Model Parameters"})
           ]
         )
         |> allow_upload(:csv,
           accept: ~w(.csv),
           auto_upload: true,
           max_entries: 1,
           max_file_size: 20_000_000
         )}

      {:error, message} ->
        {:ok, socket |> put_flash(:error, message) |> redirect(to: ~p"/workspaces/course_author")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl p-8 space-y-6">
      <h1 class="text-2xl font-bold">Learning Model Parameters</h1>
      <p>
        Download all current objectives and activities, edit their LKT-AOA values, and upload the CSV.
        Changes apply to the working publication and must be published to reach course sections.
      </p>
      <.link
        href={~p"/learning_model_parameters/#{@project.slug}/download"}
        class="inline-block text-primary underline"
      >
        Generate and Download
      </.link>
      <p>
        Edit <code>beta_lo</code>
        for objectives. For activities, edit the numbers in the <code>beta_difficulty</code>
        JSON object, keeping its part IDs. Missing values export as zero.
        Titles and child IDs are informational and are not imported.
      </p>
      <p>Only changed values create revisions. An invalid row rejects the entire upload.</p>
      <.form
        for={%{}}
        id="parameter-upload"
        phx-submit="upload"
        phx-change="validate"
        class="space-y-3"
      >
        <label for={@uploads.csv.ref} class="block">CSV file (up to 20 MB)</label>
        <.live_file_input upload={@uploads.csv} disabled={@importing?} />
        <p :for={error <- upload_errors(@uploads.csv)} role="alert">{upload_error(error)}</p>
        <div :for={entry <- @uploads.csv.entries}>
          <span>{entry.client_name} — {entry.progress}%</span>
          <progress
            value={entry.progress}
            max="100"
            aria-label={"Upload progress for #{entry.client_name}"}
          >
            {entry.progress}%
          </progress>
          <p :for={error <- upload_errors(@uploads.csv, entry)} role="alert">{upload_error(error)}</p>
          <button
            type="button"
            phx-click="cancel"
            phx-value-ref={entry.ref}
            class="underline"
            disabled={@importing?}
          >
            Remove
          </button>
        </div>
        <button
          type="submit"
          class="rounded bg-primary px-4 py-2 text-white disabled:opacity-50"
          disabled={@importing? or !upload_ready?(@uploads.csv)}
        >
          Upload
        </button>
      </.form>
      <p :if={@importing?} role="status">Importing parameters…</p>
    </div>
    """
  end

  @impl true
  def handle_event("validate", _, socket), do: {:noreply, socket}

  def handle_event(event, _, %{assigns: %{importing?: true}} = socket)
      when event in ["upload", "cancel"], do: {:noreply, socket}

  def handle_event("cancel", %{"ref" => ref}, socket),
    do: {:noreply, cancel_upload(socket, :csv, ref)}

  def handle_event("upload", _, socket) do
    case upload_ready?(socket.assigns.uploads.csv) do
      true ->
        # Keep LiveView's temporary file until the async task finishes. Consuming
        # it here would delete it before the task could read it.
        [path] =
          consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
            {:postpone, path}
          end)

        %{project: project, current_author: author} = socket.assigns

        {:noreply,
         socket
         |> assign(importing?: true)
         |> start_async(:import_parameters, fn ->
           ParameterCsv.import(project, author, File.stream!(path, [:trim_bom]))
         end)}

      false ->
        {:noreply,
         put_flash(socket, :error, "Select a valid CSV and wait for the upload to finish.")}
    end
  end

  @impl true
  def handle_async(:import_parameters, {:ok, {:ok, counts}}, socket) do
    finish_import(
      socket,
      :info,
      "Updated #{counts.changed} resources; #{counts.unchanged} unchanged."
    )
  end

  def handle_async(:import_parameters, {:ok, {:error, message}}, socket) do
    finish_import(socket, :error, message)
  end

  def handle_async(:import_parameters, {:exit, reason}, socket) do
    Logger.error(
      "Learning-model CSV import failed: #{inspect(reason, limit: 10, printable_limit: 1000)}"
    )

    finish_import(socket, :error, "The import failed. Please try again.")
  end

  defp finish_import(socket, kind, message) do
    consume_uploaded_entries(socket, :csv, fn _meta, _entry -> {:ok, :done} end)
    {:noreply, socket |> assign(importing?: false) |> put_flash(kind, message)}
  end

  # The same readiness check guards the button and server event. Auto-upload moves
  # the file first; submitting applies its values only once the transfer is complete.
  defp upload_ready?(%{entries: [entry]} = upload) do
    entry.done? and upload_errors(upload) == [] and upload_errors(upload, entry) == []
  end

  defp upload_ready?(_upload), do: false

  defp upload_error(:too_large), do: "The file exceeds 20 MB."
  defp upload_error(:too_many_files), do: "Select one CSV file."
  defp upload_error(:not_accepted), do: "Select a .csv file."
  defp upload_error(_), do: "The file could not be uploaded."
end
