defmodule OliWeb.Admin.IngestV2 do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Repo
  alias Oli.Accounts.Author
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Breadcrumb
  alias Oli.Interop.Ingest.ScalableIngest, as: Ingest

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

    state = Oli.Interop.Ingest.State.new()

    pid = self()

    state = %{
      state
      | author: author,
        notify_step_start: fn step, num_tasks -> send(pid, {:step_start, step, num_tasks}) end,
        notify_step_progress: fn detail -> send(pid, {:step_progress, detail}) end
    }

    {:ok,
     assign(socket,
       breadcrumbs: set_breadcrumbs(),
       author: author,
       uploaded_files: [],
       uploaded_content: nil,
       upload_errors: [],
       error: nil,
       progress_step: "",
       progress_total_tasks: 0,
       progress_task_detail: "",
       progress_count_tasks: 0,
       preprocessed: false,
       state: state
     )
     |> allow_upload(:digest, accept: ~w(.zip), max_entries: 1)}
  end

  @impl true
  def render(assigns) do
    ~F"""
    <div class="container">
      <h3 class="display-6">Course Ingestion</h3>
      <p class="lead">Upload a course digest archive and convert into a Torus project.</p>
      <hr class="my-4"/>

      <form id="json-upload" phx-change="validate" phx-submit="ingest">
        <div class="form-group">
          <label>Step 1. Select a Course Archive</label>
          <div class="flex my-3" phx-drop-target={@uploads.digest.ref}>
            { live_file_input @uploads.digest }
          </div>
        </div>

        <div class="form-group">
          <label>Step 2. Upload Course Archive for Ingestion Validation and Preprocessing</label>
          <div>
            <button type="submit" class="btn btn-primary" phx-disable-with="Processing...">
              Upload
            </button>
          </div>
        </div>

        <div class="form-group">
          <label>Step 3. Upon successful ingestion, you will then be redirected
          to the Overview page of the new project.</label>
        </div>
      </form>

      <hr class="my-4"/>

      {#if @progress_step != ""}
        <div class="alert alert-secondary" role="alert">
          <h4 class="alert-heading">{@progress_step}</h4>

        {#if @progress_total_tasks > 0}
          <div class="progress">
            <div class="progress-bar" role="progressbar" style={width(assigns)} aria-valuenow={now(assigns)} aria-valuemin="0" aria-valuemax="100"></div>
          </div>
        {/if}

        </div>
      {/if}

      {#if @preprocessed}
        <button class="btn btn-primary" phx-click="process" phx-disable-with="Processing...">
          Ingest
        </button>

        <ul>
        {#for e <- @state.errors}
          <li>{e}</li>
        {/for}
        </ul>
      {/if}

    </div>
    """
  end

  defp width(assigns) do
    "width: #{assigns.progress_count_tasks / assigns.progress_total_tasks * 100}%"
  end

  defp now(assigns) do
    "#{assigns.progress_count_tasks / assigns.progress_total_tasks * 100}"
  end

  def handle_event("process", _params, socket) do
    socket =
      case Oli.Interop.Ingest.Processor.process(socket.assigns.state) do
        {:ok, state} -> assign(socket, state: state)
        {:error, e} -> assign(socket, error: e)
      end

    {:noreply, socket}
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
    with path_upload <-
           consume_uploaded_entries(socket, :digest, fn %{path: path}, _entry -> path end) do
      state = Oli.Interop.Ingest.State.new()

      pid = self()

      state = %{
        state
        | notify_step_start: fn step, num_tasks -> send(pid, {:step_start, step, num_tasks}) end,
          notify_step_progress: fn detail -> send(pid, {:step_progress, detail}) end
      }

      Task.async(fn ->
        state = Ingest.unzip_then_preprocess(socket.assigns.state, hd(path_upload))
        send(pid, {:finish_preprocess, state})
      end)

      {:noreply, assign(socket, state: state, preprocessed: false)}
    else
      error ->
        {:noreply, assign(socket, error: error)}
    end
  end

  @impl true
  def handle_info({:step_start, step, num_tasks}, socket) do
    step_descriptor =
      Oli.Interop.Ingest.State.step_descriptors()
      |> Map.new()
      |> Map.get(step)

    {:noreply,
     assign(socket,
       progress_step: step_descriptor,
       progress_count_tasks: 0,
       progress_total_tasks: num_tasks
     )}
  end

  @impl true
  def handle_info({:step_progress, detail}, socket) do
    {:noreply,
     assign(socket,
       progress_count_tasks: socket.assigns.progress_count_tasks + 1,
       progress_task_detail: detail
     )}
  end

  def handle_info({:finish_preprocess, state}, socket) do
    {:noreply,
     assign(socket,
       state: state,
       progress_step: "",
       preprocessed: true
     )}
  end

  def handle_info(_, socket) do
    # needed to ignore results of Task invocation
    {:noreply, socket}
  end
end
