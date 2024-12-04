defmodule OliWeb.Datashop.AnalyticsLive do
  @moduledoc """
  LiveView implementation of datashop analytics view.
  """

  use OliWeb, :live_view
  use OliWeb.Common.Modal

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.Authoring.Broadcaster.Subscriber
  alias Oli.Authoring.{Broadcaster, Course}
  alias Oli.Delivery.Sections.{Browse, BrowseOptions}
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{Breadcrumb, PagedTable, SessionContext, TextSearch}
  alias OliWeb.Datashop.SectionsTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Components.Project.AsyncExporter
  alias OliWeb.Components.Modal
  alias Phoenix.LiveView.JS

  @limit 25

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx
  on_mount OliWeb.LiveSessionPlugs.SetProject

  def mount(_params, _session, socket) do
    ctx = socket.assigns.ctx
    project = socket.assigns.project
    selected_sections = MapSet.new([])

    ## Setup table data
    # Sections whose base project is the current project
    sections =
      Browse.browse_sections(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :title},
        %BrowseOptions{
          project_id: project.id,
          blueprint_id: nil,
          text_search: nil,
          active_today: false,
          filter_status: :active,
          filter_type: nil,
          institution_id: nil
        }
      )

    {:ok, table_model} = SectionsTableModel.new(ctx, sections, selected_sections)

    total_count = determine_total(sections)

    ## Setup Datashop export status and Pub/Sub subscription
    {datashop_export_status, datashop_export_url, datashop_export_timestamp} =
      case Course.datashop_export_status(project) do
        {:available, url, timestamp} -> {:available, url, timestamp}
        {:expired, _, _} -> {:expired, nil, nil}
        {status} -> {status, nil, nil}
      end

    # Subscribe to any raw analytics snapshot progress updates for this project
    Subscriber.subscribe_to_datashop_export_status(project.slug)
    Subscriber.subscribe_to_datashop_export_batch_started(project.slug)

    socket =
      assign(socket,
        ctx: ctx,
        breadcrumbs: [Breadcrumb.new(%{full_title: "Datashop Analytics"})],
        title: "Datashop Analytics | " <> project.title,
        table_model: table_model,
        total_count: total_count,
        datashop_export_status: datashop_export_status,
        datashop_export_url: datashop_export_url,
        datashop_export_timestamp: datashop_export_timestamp,
        datashop_export_current_batch: nil,
        datashop_export_batch_count: nil,
        selected_sections: selected_sections
      )

    {:ok, socket}
  end

  defp determine_total(sections) do
    case(sections) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  def handle_params(params, _, socket) do
    table_model =
      OliWeb.Common.Table.SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = get_int_param(params, "offset", 0)
    text_search = get_param(params, "text_search", "")
    project = socket.assigns.project

    sections =
      Browse.browse_sections(
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        %BrowseOptions{
          project_id: project.id,
          blueprint_id: nil,
          text_search: text_search,
          active_today: false,
          filter_status: :active,
          filter_type: nil,
          institution_id: nil
        }
      )

    displayed_sections = Enum.map(sections, & &1.id)

    selected_sections =
      MapSet.filter(socket.assigns.selected_sections, fn s -> s in displayed_sections end)

    table_model =
      table_model
      |> Map.put(:rows, sections)
      |> Map.update!(:data, fn data ->
        %{data | selected_sections: selected_sections}
      end)

    total_count = determine_total(sections)

    {:noreply,
     assign(socket,
       offset: offset,
       table_model: table_model,
       total_count: total_count,
       text_search: text_search,
       selected_sections: selected_sections
     )}
  end

  attr(:breadcrumbs, :any, default: [Breadcrumb.new(%{full_title: "Datashop Analytics"})])
  attr(:title, :string, default: "Datashop Analytics")

  attr(:tabel_model, :map)
  attr(:total_count, :integer, default: 0)
  attr(:offset, :integer, default: 0)
  attr(:limit, :integer, default: @limit)
  attr(:text_search, :string, default: "")
  attr(:selected_sections, :map, default: MapSet.new([]))

  def render(assigns) do
    ~H"""
    <Modal.modal
      id="generate_datashop_export_modal"
      class="w-1/2"
      on_confirm={
        JS.push("generate_datashop_snapshot")
        |> Modal.hide_modal("generate_datashop_export_modal")
      }
    >
      <:title>Generate Datashop Export</:title>
      <div class="flex flex-col items-center justify-center text-center p-4">
        <div class="text-xl">
          Are you sure you want to generate a Datashop export?
        </div>
      </div>

      <:confirm>Confirm</:confirm>
    </Modal.modal>
    <div class="container mx-auto">
      <div class="container mb-4">
        <div class="flex justify-between items-center">
          <div class="flex-grow">
            <TextSearch.render
              id="text-search"
              reset="text_search_reset"
              change="text_search_change"
              text={@text_search}
              event_target={nil}
            />
          </div>

          <AsyncExporter.datashop
            ctx={@ctx}
            on_generate_datashop_snapshot={Modal.show_modal("generate_datashop_export_modal")}
            on_kill="kill_datashop_snapshot"
            datashop_export_status={@datashop_export_status}
            datashop_export_url={@datashop_export_url}
            datashop_export_timestamp={@datashop_export_timestamp}
            datashop_export_current_batch={@datashop_export_current_batch}
            datashop_export_batch_count={@datashop_export_batch_count}
            disabled={Enum.empty?(@selected_sections)}
          />
        </div>
      </div>

      <div class="grid grid-cols-12">
        <div id="projects-table" class="col-span-12">
          <PagedTable.render
            page_change="paged_table_page_change"
            sort="paged_table_sort"
            total_count={@total_count}
            filter={@text_search}
            limit={@limit}
            offset={@offset}
            table_model={@table_model}
          />
        </div>
      </div>
    </div>
    """
  end

  def patch_with(socket, changes) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Datashop.AnalyticsLive,
           socket.assigns.project.slug,
           Map.merge(
             %{
               sort_by: socket.assigns.table_model.sort_by_spec.name,
               sort_order: socket.assigns.table_model.sort_order,
               offset: socket.assigns.offset,
               text_search: socket.assigns.text_search
             },
             changes
           )
         ),
       replace: true
     )}
  end

  def handle_event("toggle_section", %{"section_id" => section_id} = params, socket) do
    toggle_fn =
      case params["value"] do
        "on" -> &MapSet.put/2
        _ -> &MapSet.delete/2
      end

    selected_sections = toggle_fn.(socket.assigns.selected_sections, section_id)

    data = %{socket.assigns.table_model.data | selected_sections: selected_sections}
    table_model = Map.put(socket.assigns.table_model, :data, data)

    {:noreply, assign(socket, table_model: table_model, selected_sections: selected_sections)}
  end

  def handle_event("generate_datashop_snapshot", _params, socket) do
    project = socket.assigns.project

    selected_sections = MapSet.to_list(socket.assigns.selected_sections)

    case Course.generate_datashop_snapshot(project, selected_sections) do
      {:ok, _job} ->
        Broadcaster.broadcast_datashop_export_status(project.slug, {:in_progress})

        {:noreply, socket}

      {:error, _changeset} ->
        socket =
          socket
          |> put_flash(:error, "Datashop snapshot could not be generated.")

        {:noreply, socket}
    end
  end

  def handle_event("kill_datashop_snapshot", _params, socket) do
    Course.kill_datashop_export(socket.assigns.project.slug, "datashop_export")
    Broadcaster.broadcast_datashop_export_status(socket.assigns.project.slug, {:not_available})

    socket =
      socket
      |> put_flash(:info, "Snapshots killed")

    {:noreply, socket}
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end

  def handle_info(
        {:datashop_export_status, {:available, datashop_export_url, datashop_export_timestamp}},
        socket
      ) do
    socket =
      socket
      |> assign(
        datashop_export_status: :available,
        datashop_export_url: datashop_export_url,
        datashop_export_timestamp: datashop_export_timestamp
      )
      |> maybe_reset_current_batch(:available)

    {:noreply, socket}
  end

  def handle_info(
        {:datashop_export_status, {:error, _e}},
        socket
      ) do
    socket =
      socket
      |> assign(datashop_export_status: :error)
      |> maybe_reset_current_batch(:error)

    {:noreply, socket}
  end

  def handle_info({:datashop_export_status, {status}}, socket) do
    socket =
      socket
      |> assign(datashop_export_status: status)
      |> maybe_reset_current_batch(status)

    {:noreply, socket}
  end

  def handle_info(
        {:datashop_export_batch_started, {:batch_started, current_batch, batch_count}},
        socket
      ) do
    {:noreply,
     assign(socket,
       datashop_export_current_batch: current_batch,
       datashop_export_batch_count: batch_count
     )}
  end

  defp maybe_reset_current_batch(socket, :in_progress), do: socket

  defp maybe_reset_current_batch(socket, _status),
    do: assign(socket, datashop_export_current_batch: nil, datashop_export_batch_count: nil)
end
