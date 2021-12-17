defmodule OliWeb.Sections.SectionsView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb, Check}
  alias Oli.Accounts
  alias Oli.Delivery.Sections.{Browse, BrowseOptions}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.SectionsTableModel

  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params

  @limit 25
  @default_options %BrowseOptions{
    show_deleted: false,
    institution_id: nil,
    blueprint_id: nil,
    active_only: false,
    text_search: ""
  }

  prop author, :any
  data breadcrumbs, :any
  data title, :string, default: "All Course Sections"

  data sections, :list, default: []

  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: @limit
  data options, :any

  def set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb()
    |> breadcrumb()
  end

  def breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "All Course Sections",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
        })
      ]
  end

  def mount(_, %{"current_author_id" => author_id} = session, socket) do
    author = Accounts.get_author!(author_id)

    sections =
      Browse.browse_sections(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :title},
        @default_options
      )

    total_count = determine_total(sections)

    {:ok, table_model} = SectionsTableModel.new(sections, Map.get(session, "local_tz"))

    {:ok,
     assign(socket,
       breadcrumbs: set_breadcrumbs(),
       author: author,
       sections: sections,
       total_count: total_count,
       table_model: table_model,
       options: @default_options
     )}
  end

  defp determine_total(projects) do
    case(projects) do
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

    options = %BrowseOptions{
      text_search: get_param(params, "text_search", ""),
      show_deleted: get_boolean_param(params, "show_deleted", false),
      active_only: get_boolean_param(params, "active_only", false),
      # This view is currently for all institutions and all root products
      institution_id: nil,
      blueprint_id: nil
    }

    sections =
      Browse.browse_sections(
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    table_model = Map.put(table_model, :rows, sections)
    total_count = determine_total(sections)

    {:noreply,
     assign(socket,
       offset: offset,
       sections: sections,
       table_model: table_model,
       total_count: total_count,
       options: options
     )}
  end

  def render(assigns) do
    ~F"""
    <div>

      <Check class="mr-4" checked={@options.show_deleted} click="show_deleted">Show deleted sections</Check>
      <Check checked={@options.active_only} click="active_only">Show only active sections</Check>

      <div class="mb-3"/>

      <TextSearch id="text-search" text={@options.text_search} />

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
               text_search: socket.assigns.options.text_search,
               show_deleted: socket.assigns.options.show_deleted,
               active_only: socket.assigns.options.active_only
             },
             changes
           )
         ),
       replace: true
     )}
  end

  def handle_event("show_deleted", _, socket),
    do: patch_with(socket, %{show_deleted: !socket.assigns.options.show_deleted})

  def handle_event("active_only", _, socket),
    do: patch_with(socket, %{active_only: !socket.assigns.options.active_only})

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end
end
