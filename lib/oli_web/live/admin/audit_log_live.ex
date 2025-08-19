defmodule OliWeb.Admin.AuditLogLive do
  use OliWeb, :live_view

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.Auditing
  alias Oli.Auditing.{BrowseOptions, LogEvent}
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{Breadcrumb, PagedTable, TextSearch}
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
    # Check if user has system admin role
    if !Oli.Accounts.has_admin_role?(socket.assigns.current_author, :system_admin) do
      {:ok,
       socket
       |> put_flash(:error, "You are not authorized to view this page")
       |> redirect(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.AdminView))}
    else
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
      <div class="mb-4">
        <h3 class="text-lg font-semibold mb-2">Filters</h3>
        <div class="flex flex-wrap gap-4">
          <div class="flex-1 min-w-[300px]">
            <TextSearch.render id="text-search" text={@options.text_search} />
          </div>

          <div class="min-w-[200px]">
            <label class="block text-sm font-medium text-gray-700 mb-1">Event Type</label>
            <select
              id="event_type_filter"
              name="event_type"
              phx-hook="SelectListener"
              phx-change="filter_event_type"
              class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
            >
              <option value="">All Events</option>
              <%= for event_type <- @event_types do %>
                <option value={event_type} selected={@options.event_type == event_type}>
                  {event_type |> to_string() |> String.replace("_", " ") |> String.capitalize()}
                </option>
              <% end %>
            </select>
          </div>

          <div class="min-w-[200px]">
            <label class="block text-sm font-medium text-gray-700 mb-1">Actor Type</label>
            <select
              id="actor_type_filter"
              name="actor_type"
              phx-hook="SelectListener"
              phx-change="filter_actor_type"
              class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
            >
              <option value="">All Actors</option>
              <option value="user" selected={@options.actor_type == :user}>Users</option>
              <option value="author" selected={@options.actor_type == :author}>Authors</option>
            </select>
          </div>
        </div>
      </div>

      <div class="mb-3" />

      <PagedTable.render
        filter={@options.text_search}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}
      />

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

            <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
              <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                <div class="sm:flex sm:items-start">
                  <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
                    <h3 class="text-lg leading-6 font-medium text-gray-900" id="modal-title">
                      Event Details
                    </h3>
                    <div class="mt-2">
                      <pre class="text-sm text-gray-500 whitespace-pre-wrap overflow-x-auto">{Jason.encode!(@modal_details, pretty: true)}</pre>
                    </div>
                  </div>
                </div>
              </div>
              <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
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

  # Specific event handlers must come before the generic handler
  # These handlers receive events from the SelectListener hook which sends {id, value}
  def handle_event("filter_event_type", %{"id" => _id, "value" => value}, socket) do
    event_type =
      case value do
        "" -> nil
        "nil" -> nil
        v -> String.to_existing_atom(v)
      end

    patch_with(socket, %{event_type: event_type, offset: 0})
  end

  def handle_event("filter_actor_type", %{"id" => _id, "value" => value}, socket) do
    actor_type =
      case value do
        "" -> nil
        "nil" -> nil
        v -> String.to_existing_atom(v)
      end

    patch_with(socket, %{actor_type: actor_type, offset: 0})
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
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end

  defp get_atom_param(params, key, default) do
    case Map.get(params, key) do
      nil -> default
      "" -> default
      value -> String.to_existing_atom(value)
    end
  end
end
