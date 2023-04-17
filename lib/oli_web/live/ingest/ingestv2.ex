defmodule OliWeb.Admin.IngestV2 do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Repo
  alias Oli.Accounts.Author
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Breadcrumb
  alias Oli.Interop.Ingest.ScalableIngest, as: Ingest
  alias OliWeb.Common.Properties.{Groups, Group, ReadOnly}
  alias Oli.Interop.Ingest.Preprocessor
  alias OliWeb.Common.PagedTable
  alias OliWeb.Common.Check
  alias OliWeb.Admin.Ingest.ErrorsTableModel
  import OliWeb.DelegatedEvents

  prop author, :any
  data breadcrumbs, :any
  data title, :string, default: "Ingest Project"

  defp ingest_file(author) do
    "_digests/#{author.id}-digest.zip"
  end

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
    ingest_file = ingest_file(author)

    if File.exists?(ingest_file) do
      {:ok,
       assign(socket,
         breadcrumbs: set_breadcrumbs(),
         author: author,
         error: nil,
         progress_step: "",
         progress_total_tasks: 0,
         progress_task_detail: "",
         progress_count_tasks: 0,
         # [:ready, :waiting, :preprocessed, :processed, :failed]
         ingestion_step: :ready,
         resource_counts: %{},
         state: state,
         offset: 0,
         limit: 20,
         table_model: nil,
         bypass_validation: false,
         total_count: 0
       )}
    else
      {:ok, Phoenix.LiveView.redirect(socket, to: Routes.ingest_path(OliWeb.Endpoint, :index))}
    end
  end

  defp render_ready(assigns) do
    ~F"""
    {#if @ingestion_step == :ready}
      <div class="alert alert-secondary mb-3" role="alert">
        <h4 class="alert-heading">Ready for Ingest</h4>
        <Check checked={@bypass_validation} click="bypass">Bypass JSON validation <strong>(only use in development use cases)</strong></Check>
        <div class="mt-4">
          <button class="btn btn-primary" phx-click="preprocess">Preprocess</button>
        </div>
      </div>
    {/if}
    """
  end

  defp render_preprocessed(assigns) do
    ~F"""
    {#if @ingestion_step == :preprocessed}
    <Groups>
      <Group label="Project" description="Details about the project">
        <ReadOnly label="Title" value={@state.project_details["title"]}/>
        <ReadOnly label="Description" value={@state.project_details["description"]}/>
        <ReadOnly label="SVN URL" value={@state.project_details["svnRoot"]}/>
      </Group>
      <Group label="Resource Counts" description="Details about the resources">
        <ReadOnly label="Tags" value={@resource_counts.tags}/>
        <ReadOnly label="Bibliography Entries" value={@resource_counts.bib_entries}/>
        <ReadOnly label="Objectives" value={@resource_counts.objectives}/>
        <ReadOnly label="Activities" value={@resource_counts.activities}/>
        <ReadOnly label="Pages" value={@resource_counts.pages}/>
        <ReadOnly label="Products" value={@resource_counts.products}/>
        <ReadOnly label="Media Items" value={@resource_counts.media_items}/>
      </Group>
      <Group label="Errors" description="Errors encountered during preprocessing">
        <PagedTable
          allow_selection={false}
          filter={nil}
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}/>
      </Group>
      <Group label="Process" description="">
        <button class="btn btn-primary" phx-click="process" phx-disable-with="Processing...">
          Proceed and ingest this course project
        </button>
      </Group>
    </Groups>
    {/if}
    """
  end

  defp render_processed(assigns) do
    ~F"""
    {#if @ingestion_step == :processed}
      <h4>Ingest succeeded</h4>

      <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.OverviewLive, @state.project.slug)}>Access your new course here</a>
    {/if}
    """
  end

  defp render_progress(assigns) do
    ~F"""
      {#if @progress_step != ""}
      <div class="alert alert-secondary" role="alert">
        <h4 class="alert-heading">{@progress_step}</h4>

      {#if @progress_total_tasks > 0}
        <div class="progress">
          <div id={@progress_step} class="progress-bar" role="progressbar" style={width(assigns)} aria-valuenow={now(assigns)} aria-valuemin="0" aria-valuemax="100"></div>
        </div>
      {/if}

      </div>

    {/if}
    """
  end

  defp render_failed(assigns) do
    ~F"""
    {#if @ingestion_step == :failed}
    <div class="alert alert-danger" role="alert">
      <h4 class="alert-heading">Ingest Processing Failed</h4>
      {@error}
    </div>
    {/if}
    """
  end

  @impl true
  def render(assigns) do
    ~F"""
    <div class="container">
      <h3 class="display-6">Course Ingestion</h3>
      <hr class="my-4"/>

      {render_ready(assigns)}
      {render_preprocessed(assigns)}
      {render_processed(assigns)}
      {render_failed(assigns)}
      {render_progress(assigns)}

    </div>
    """
  end

  defp width(assigns) do
    "width: #{assigns.progress_count_tasks / assigns.progress_total_tasks * 100}%"
  end

  defp now(assigns) do
    "#{assigns.progress_count_tasks / assigns.progress_total_tasks * 100}"
  end

  @impl true
  def handle_event("bypass", _params, socket) do
    {:noreply, assign(socket, bypass_validation: !socket.assigns.bypass_validation)}
  end

  def handle_event("preprocess", _, socket) do
    pid = self()
    state = Oli.Interop.Ingest.State.new()

    state = %{
      state
      | author: socket.assigns.author,
        errors: [],
        bypass_validation: socket.assigns.bypass_validation,
        notify_step_start: fn step, num_tasks ->
          send(pid, {:step_start, step, num_tasks})
        end,
        notify_step_progress: fn detail -> send(pid, {:step_progress, detail}) end
    }

    Task.async(fn ->
      state =
        Ingest.unzip(state, ingest_file(socket.assigns.author))
        |> Preprocessor.preprocess()

      send(pid, {:finish_preprocess, state})
    end)

    {:noreply, assign(socket, ingestion_step: :waiting)}
  end

  @impl true
  def handle_event("process", _params, socket) do
    pid = self()

    Task.async(fn ->
      case Oli.Interop.Ingest.Processor.process(socket.assigns.state) do
        {:ok, state} -> send(pid, {:finish_process, state})
        {:error, e} -> send(pid, {:failed_process, e})
        _ -> send(pid, {:failed_process, "unknown"})
      end
    end)

    {:noreply,
     assign(socket,
       ingestion_step: :processing
     )}
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &PagedTable.handle_delegated/4
    ])
  end

  def patch_with(socket, changes) do
    {offset, _} =
      Map.get(changes, :offset, socket.assigns.offset |> Integer.to_string())
      |> Integer.parse()

    rows = Enum.slice(socket.assigns.state.errors, offset, socket.assigns.limit)

    table_model =
      ErrorsTableModel.update_rows(
        socket.assigns.table_model,
        rows
      )

    {:noreply, assign(socket, offset: offset, table_model: table_model)}
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
    socket.assigns.author
    |> ingest_file
    |> File.rm()

    {:ok, table_model} =
      Enum.slice(state.errors, socket.assigns.offset, socket.assigns.limit)
      |> ErrorsTableModel.new()

    {:noreply,
     assign(socket,
       state: state,
       progress_step: "",
       resource_counts: %{
         tags: Enum.count(state.tags),
         bib_entries: Enum.count(state.bib_entries),
         objectives: Enum.count(state.objectives),
         activities: Enum.count(state.activities),
         pages: Enum.count(state.pages),
         products: Enum.count(state.products),
         media_items: Enum.count(state.media_manifest["mediaItems"])
       },
       total_count: Enum.count(state.errors),
       table_model: table_model,
       ingestion_step: :preprocessed
     )}
  end

  def handle_info({:finish_process, state}, socket) do
    {:noreply,
     assign(socket,
       state: state,
       progress_step: "",
       ingestion_step: :processed
     )}
  end

  def handle_info({:failed_process, e}, socket) do
    {:noreply,
     assign(socket,
       progress_step: "",
       error: e,
       ingestion_step: :failed
     )}
  end

  def handle_info(_, socket) do
    # needed to ignore results of Task invocation
    {:noreply, socket}
  end
end
