defmodule OliWeb.Workspaces.CourseAuthor.DatasetDetailsLive do
  use OliWeb, :live_view

  alias Oli.Analytics.Datasets
  alias OliWeb.Router.Helpers, as: Routes

  @impl Phoenix.LiveView
  def mount(%{"project_id" => project_slug, "job_id" => job_id}, _session, socket) do

    # Get the job and verify that it pertains to this project
    case Datasets.get_job(job_id, project_slug) do

      nil ->
        {:ok,
          Phoenix.LiveView.redirect(socket,
            to: Routes.static_page_path(OliWeb.Endpoint, :not_found)
        )}

      job ->

        # If the job status is success, we fetch and parse the job result
        # manifest in a separate task
        results_manifest = case job.status == :success do
          true ->
            pid = self()
            Task.async(fn ->
              result = Datasets.fetch_manifest(job)
              send(pid, {:manifest, result})
            end)

            :waiting

          false ->
            nil

        end

        {:ok,
          assign(socket,
            active: :datasets,
            job: job,
            results_manifest: results_manifest
          )
        }
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h2 id="header_id" class="pb-2">Dataset Job Details</h2>
    <div class="card mt-5 mb-5">
      <div class="card-body">
        <p class="card-text">
          <strong>Job Id:</strong> <%= @job.job_id %><br>
          <strong>Job Run Id:</strong> <%= @job.job_run_id %><br>
          <strong>Job Type:</strong> <%= @job.job_type %><br>
          <strong>Status:</strong> <%= @job.status %><br>
          <strong>Notify:</strong> <%= @job.notify_emails |> Enum.join(" ") %><br>
          <strong>Started:</strong> <%= @job.inserted_at %><br>
          <strong>Finished:</strong> <%= @job.finished_on %><br>
          <strong>Started By:</strong> <%= @job.initiator_email %>
        </p>
      </div>
    </div>
    <%= render_manifest(assigns) %>
    """
  end

  defp render_manifest(%{results_manifest: nil} = assigns) do
    ~H"""

    """
  end

  defp render_manifest(%{results_manifest: :waiting} = assigns) do
    ~H"""
    Fetching the job results...
    """
  end

  defp render_manifest(%{results_manifest: {:ok, %{"chunks" => []}}} = assigns) do

    ~H"""
    <div class="card mt-5 mb-5">
      <div class="card-body">
        <p class="card-text">
          <strong>No files were generated by this job.</strong>
        </p>
      </div>
    </div>
    """
  end

  defp render_manifest(%{results_manifest: {:ok, manifest}} = assigns) do

    assigns = Map.merge(assigns, %{manifest: manifest})

    ~H"""
    <div class="card mt-5 mb-5">
      <div class="card-body">
        <p class="card-text">
          <strong><%= Enum.count(@manifest["chunks"])%> file(s) total:</strong>
        </p>
        <table class="table table-striped">
          <thead>
            <tr>
              <th>File</th>
            </tr>
          </thead>
          <tbody>
            <%= for file <- @manifest["chunks"] do %>
              <tr>
                <td><a href={file}><%= file %></a></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp render_manifest(%{results_manifest: {:error, _error}} = assigns) do
    ~H"""
    An problem occurred while fetching the job results. Perhaps try again later.
    """
  end

  @impl Phoenix.LiveView
  def handle_event("download_all", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:manifest, result}, socket) do
\
    {:noreply,
      assign(socket,
        results_manifest: result
      )
    }
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

end
