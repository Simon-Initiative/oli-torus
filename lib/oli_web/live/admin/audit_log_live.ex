defmodule OliWeb.Admin.AuditLogLive do
  use OliWeb, :live_view

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.Auditing
  alias Oli.Auditing.{BrowseOptions, LogEvent}
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{Breadcrumb, StripedPagedTable, SearchInput, PagingParams}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Admin.AuditLog.TableModel

  @limit 25
  @default_options %BrowseOptions{
    text_search: "",
    event_type: nil,
    actor_type: nil
  }

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
          full_title: "Audit Log",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
        })
      ]
  end

  def mount(_, _session, socket) do
    events =
      Auditing.browse_events(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :desc, field: :inserted_at},
        @default_options
      )

    total_count = SortableTableModel.determine_total(events)

    ctx = socket.assigns.ctx
    {:ok, table_model} = TableModel.new(events, ctx)

    {:ok,
     assign(socket,
       title: "Audit Log",
       breadcrumbs: set_breadcrumbs(),
       events: events,
       total_count: total_count,
       table_model: table_model,
       options: @default_options,
       show_details_modal: false,
       modal_details: nil,
       event_types: LogEvent.event_types()
     )}
  end

  def handle_params(params, _, socket) do
    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = get_int_param(params, "offset", 0)

    options = %BrowseOptions{
      text_search: get_param(params, "text_search", ""),
      event_type: get_atom_param(params, "event_type", nil),
      actor_type: get_atom_param(params, "actor_type", nil)
    }

    events =
      Auditing.browse_events(
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    table_model = Map.put(table_model, :rows, events)
    total_count = SortableTableModel.determine_total(events)

    {:noreply,
     assign(socket,
       offset: offset,
       events: events,
       table_model: table_model,
       total_count: total_count,
       options: options
     )}
  end

  attr(:breadcrumbs, :any)
  attr(:events, :list, default: [])
  attr(:table_model, :map)
  attr(:total_count, :integer, default: 0)
  attr(:offset, :integer, default: 0)
  attr(:limit, :integer, default: @limit)
  attr(:options, :any)
  attr(:event_types, :list, default: [])
  attr(:show_details_modal, :boolean, default: false)
  attr(:modal_details, :map, default: nil)

  def render(assigns) do
    ~H"""
    <div>
      <div class="flex flex-row justify-between items-center px-4">
        <div class="flex flex-col">
          <span class="text-2xl font-bold text-[#353740] dark:text-[#EEEBF5] leading-loose">
            Audit Log
          </span>
          <div class="flex flex-row gap-4 mt-2 items-center">
            <form phx-change="change_event_type" class="flex flex-row">
              <select
                name="event_type"
                id="select_event_type"
                class="custom-select"
                style="width: 180px;"
              >
                <option value="" selected>Event Type</option>
                <option
                  :for={event_type <- @event_types}
                  value={event_type}
                  selected={@options.event_type == event_type}
                >
                  {event_type |> to_string() |> String.replace("_", " ") |> String.capitalize()}
                </option>
              </select>
            </form>
            <form phx-change="change_actor_type" class="flex flex-row">
              <select
                name="actor_type"
                id="select_actor_type"
                class="custom-select"
                style="width: 140px;"
              >
                <option value="" selected>Actor Type</option>
                <option value="user" selected={@options.actor_type == :user}>Users</option>
                <option value="author" selected={@options.actor_type == :author}>Authors</option>
              </select>
            </form>
          </div>
        </div>
      </div>
      <div class="flex w-fit gap-4 p-2 pr-8 mx-4 mt-3 mb-2 shadow-[0px_2px_6.099999904632568px_0px_rgba(0,0,0,0.10)] border border-[#ced1d9] dark:border-[#3B3740] dark:bg-[#000000]">
        <.form for={%{}} phx-change="text_search_change" class="w-56">
          <SearchInput.render id="text-search" name="audit_search" text={@options.text_search} />
        </.form>

        <button
          class="ml-2 mr-4 text-center text-[#353740] dark:text-[#EEEBF5] text-sm font-normal leading-none flex items-center gap-x-1 hover:text-[#006CD9] dark:hover:text-[#4CA6FF]"
          phx-click="clear_all_filters"
        >
          <OliWeb.Icons.trash /> Clear All Filters
        </button>
      </div>

      <div class="audit-log-table">
        <StripedPagedTable.render
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
          render_top_info={false}
          additional_table_class="instructor_dashboard_table"
          sort="paged_table_sort"
          page_change="paged_table_page_change"
          limit_change="paged_table_limit_change"
          show_limit_change={true}
        />
      </div>

      <%= if @show_details_modal do %>
        <div
          class="fixed z-10 inset-0 overflow-y-auto"
          aria-labelledby="modal-title"
          role="dialog"
          aria-modal="true"
        >
          <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <div
              class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"
              aria-hidden="true"
              phx-click="close_details_modal"
            >
            </div>

            <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">
              &#8203;
            </span>

            <div class="inline-block align-bottom bg-white dark:bg-gray-800 rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
              <div class="bg-white dark:bg-gray-800 px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                <div class="sm:flex sm:items-start">
                  <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
                    <h3
                      class="text-lg leading-6 font-medium text-gray-900 dark:text-gray-100"
                      id="modal-title"
                    >
                      Event Details
                    </h3>
                    <div class="mt-2">
                      <pre class="text-sm text-gray-500 dark:text-gray-400 whitespace-pre-wrap overflow-x-auto">{Jason.encode!(@modal_details, pretty: true)}</pre>
                    </div>
                  </div>
                </div>
              </div>
              <div class="bg-gray-50 dark:bg-gray-700 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                <button
                  type="button"
                  phx-click="close_details_modal"
                  class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:ml-3 sm:w-auto sm:text-sm"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def patch_with(socket, changes) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           Map.merge(
             %{
               sort_by: socket.assigns.table_model.sort_by_spec.name,
               sort_order: socket.assigns.table_model.sort_order,
               offset: socket.assigns.offset,
               text_search: socket.assigns.options.text_search,
               event_type: socket.assigns.options.event_type,
               actor_type: socket.assigns.options.actor_type
             },
             changes
           )
         ),
       replace: true
     )}
  end

  def handle_event("change_event_type", %{"event_type" => event_type}, socket) do
    event_type =
      case event_type do
        "" -> nil
        v -> String.to_existing_atom(v)
      end

    patch_with(socket, %{event_type: event_type, offset: 0})
  end

  def handle_event("change_actor_type", %{"actor_type" => actor_type}, socket) do
    actor_type =
      case actor_type do
        "" -> nil
        v -> String.to_existing_atom(v)
      end

    patch_with(socket, %{actor_type: actor_type, offset: 0})
  end

  def handle_event("text_search_change", %{"audit_search" => text}, socket) do
    patch_with(socket, %{text_search: text, offset: 0})
  end

  def handle_event("clear_all_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/audit_log")}
  end

  def handle_event("paged_table_sort", %{"sort_by" => sort_by_str}, socket) do
    current_sort_by = socket.assigns.table_model.sort_by_spec.name
    current_sort_order = socket.assigns.table_model.sort_order
    new_sort_by = String.to_existing_atom(sort_by_str)

    sort_order =
      if new_sort_by == current_sort_by, do: toggle_sort_order(current_sort_order), else: :asc

    patch_with(socket, %{sort_by: new_sort_by, sort_order: sort_order})
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    patch_with(socket, %{limit: limit, offset: offset})
  end

  def handle_event(
        "paged_table_limit_change",
        params,
        socket
      ) do
    new_limit = get_int_param(params, "limit", 20)

    new_offset =
      PagingParams.calculate_new_offset(
        socket.assigns.offset,
        new_limit,
        socket.assigns.total_count
      )

    patch_with(socket, %{limit: new_limit, offset: new_offset})
  end

  def handle_event("show_details", %{"details" => details}, socket) do
    modal_details = Jason.decode!(details)
    {:noreply, assign(socket, show_details_modal: true, modal_details: modal_details)}
  end

  def handle_event("close_details_modal", _, socket) do
    {:noreply, assign(socket, show_details_modal: false, modal_details: nil)}
  end

  # Generic handler for delegated events - must come last
  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([&StripedPagedTable.handle_delegated/4])
  end

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(_), do: :asc

  defp get_atom_param(params, key, default) do
    case Map.get(params, key) do
      nil -> default
      "" -> default
      value -> String.to_existing_atom(value)
    end
  end
end
