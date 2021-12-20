defmodule OliWeb.Admin.RegistrationsView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Accounts.Author
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Admin.RegistrationsTableModel
  alias Oli.Institutions
  alias Oli.Institutions.{RegistrationBrowseOptions}
  alias Surface.Components.Link

  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params

  @limit 25

  @default_options %RegistrationBrowseOptions{
    text_search: ""
  }

  prop author, :any
  data breadcrumbs, :any
  data title, :string, default: "LTI 1.3 Registrations"

  data registrations, :list, default: []

  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: @limit
  data options, :any

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb()
    |> breadcrumb()
  end

  def breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "LTI 1.3 Registrations",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
        })
      ]
  end

  def mount(_, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)

    registrations =
      Institutions.browse_registrations(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :issuer},
        @default_options
      )

    total_count = determine_total(registrations)

    {:ok, table_model} = RegistrationsTableModel.new(registrations)

    {:ok,
     assign(socket,
       breadcrumbs: set_breadcrumbs(),
       author: author,
       registrations: registrations,
       total_count: total_count,
       table_model: table_model,
       options: @default_options
     )}
  end

  defp determine_total(registrations) do
    case(registrations) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  def handle_params(params, _, socket) do
    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = get_int_param(params, "offset", 0)

    options = %RegistrationBrowseOptions{
      text_search: get_param(params, "text_search", "")
    }

    registrations =
      Institutions.browse_registrations(
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    table_model = Map.put(table_model, :rows, registrations)
    total_count = determine_total(registrations)

    {:noreply,
     assign(socket,
       offset: offset,
       registrations: registrations,
       table_model: table_model,
       total_count: total_count,
       options: options
     )}
  end

  def render(assigns) do
    ~F"""
    <div>

      <div class="d-flex flex-row">
        <TextSearch id="text-search" text={@options.text_search} />
        <div class="flex-grow-1"></div>
        <div>
          <Link label="Create Registration" to={Routes.registration_path(OliWeb.Endpoint, :new)} class="btn btn-sm btn-outline-primary ml-2" />
        </div>
      </div>

      <div class="mb-3"/>

      <PagedTable
        filter={@options.text_search}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}/>

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
               text_search: socket.assigns.options.text_search
             },
             changes
           )
         ),
       replace: true
     )}
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end
end
