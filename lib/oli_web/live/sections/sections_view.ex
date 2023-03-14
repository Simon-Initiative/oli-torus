defmodule OliWeb.Sections.SectionsView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.{Browse, BrowseOptions, Section}
  alias OliWeb.Common.{Breadcrumb, Check, FilterBox, PagedTable, TextSearch, SessionContext}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Sections.SectionsTableModel
  alias OliWeb.Router.Helpers, as: Routes

  @limit 25
  @default_options %BrowseOptions{
    institution_id: nil,
    blueprint_id: nil,
    text_search: "",
    active_today: false,
    filter_status: nil,
    filter_type: nil
  }
  @type_opts [:open, :lms]

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

  defp breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "All Course Sections",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
        })
      ]
  end

  def mount(_, %{"current_author_id" => _} = session, socket) do
    %SessionContext{author: author} = context = SessionContext.init(session)

    sections =
      Browse.browse_sections(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :title},
        @default_options
      )

    total_count = determine_total(sections)
    {:ok, table_model} = SectionsTableModel.new(context, sections)

    {:ok,
     assign(socket,
       context: context,
       breadcrumbs: set_breadcrumbs(),
       author: author,
       sections: sections,
       total_count: total_count,
       table_model: table_model,
       options: @default_options
     )}
  end

  def handle_params(params, _, socket) do
    table_model = SortableTableModel.update_from_params(socket.assigns.table_model, params)
    offset = get_int_param(params, "offset", 0)

    options = %BrowseOptions{
      text_search: get_param(params, "text_search", ""),
      active_today: get_boolean_param(params, "active_today", false),
      filter_status:
        get_atom_param(params, "filter_status", Ecto.Enum.values(Section, :status), nil),
      filter_type: get_atom_param(params, "filter_type", @type_opts, nil),
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
    # can't use @ notation inside sigil
    type_opts = @type_opts

    ~F"""
      <div class="container mx-auto">
        <FilterBox
          card_header_text="Browse Course Sections"
          card_body_text=""
          table_model={@table_model}
          show_sort={false}
          show_more_opts={true}>
          <TextSearch id="text-search" text={@options.text_search}/>

          <:extra_opts>
            <Check checked={@options.active_today} click="active_today">Active (start/end dates include today)</Check>

            <form :on-change="change_type" class="d-flex">
              <select name="type" id="select_type" class="custom-select custom-select mr-2">
                <option value="" selected>Type</option>
                {#for type_opt <- type_opts}
                  <option value={type_opt} selected={@options.filter_type == type_opt}>{humanize_type_opt(type_opt)}</option>
                {/for}
              </select>
            </form>

            <form :on-change="change_status" class="d-flex">
              <select name="status" id="select_status" class="custom-select custom-select mr-2">
                <option value="" selected>Status</option>
                {#for status_opt <- Ecto.Enum.values(Section, :status)}
                  <option value={status_opt} selected={@options.filter_status == status_opt}>{Phoenix.Naming.humanize(status_opt)}</option>
                {/for}
              </select>
            </form>
          </:extra_opts>
        </FilterBox>

        <div class="mb-5"/>

        <div class="sections-table">
          <PagedTable
            filter={@options.text_search}
            table_model={@table_model}
            total_count={@total_count}
            offset={@offset}
            limit={@limit}
            show_bottom_paging={false}/>
        </div>
      </div>
    """
  end

  def handle_event("active_today", _, socket),
    do: patch_with(socket, %{active_today: !socket.assigns.options.active_today})

  def handle_event("change_status", %{"status" => status}, socket),
    do: patch_with(socket, %{filter_status: status})

  def handle_event("change_type", %{"type" => type}, socket),
    do: patch_with(socket, %{filter_type: type})

  def handle_event(event, params, socket),
    do: delegate_to({event, params, socket, &__MODULE__.patch_with/2},
        [&TextSearch.handle_delegated/4, &PagedTable.handle_delegated/4])

  defp determine_total(projects) do
    case projects do
      [] -> 0
      [hd | _] -> hd.total_count
    end
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
               active_today: socket.assigns.options.active_today,
               filter_status: socket.assigns.options.filter_status,
               filter_type: socket.assigns.options.filter_type
             },
             changes
           )
         ),
       replace: true
     )}
  end

  defp humanize_type_opt(:open), do: "Open"
  defp humanize_type_opt(:lms), do: "LMS"
end
