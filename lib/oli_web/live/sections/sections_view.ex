defmodule OliWeb.Sections.SectionsView do
  use OliWeb, :live_view

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.{Browse, BrowseOptions, Section}
  alias OliWeb.Common.{Breadcrumb, Check, FilterBox, PagedTable, TextSearch}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Sections.SectionsTableModel
  alias OliWeb.Router.Helpers, as: Routes

  @limit 25
  @default_options %BrowseOptions{
    institution_id: nil,
    blueprint_id: nil,
    project_id: nil,
    text_search: "",
    active_today: false,
    filter_status: nil,
    filter_type: nil
  }
  @type_opts [:open, :lms]

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

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

  def mount(_, _session, socket) do
    ctx = socket.assigns.ctx

    sections =
      Browse.browse_sections(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :title},
        @default_options
      )

    total_count = determine_total(sections)
    {:ok, table_model} = SectionsTableModel.new(ctx, sections)

    {:ok,
     assign(socket,
       breadcrumbs: set_breadcrumbs(),
       author: socket.assigns.current_author,
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
      blueprint_id: nil,
      project_id: nil
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

  attr(:author, :any)
  attr(:breadcrumbs, :any)
  attr(:title, :string, default: "All Course Sections")
  attr(:sections, :list, default: [])
  attr(:tabel_model, :map)
  attr(:total_count, :integer, default: 0)
  attr(:offset, :integer, default: 0)
  attr(:limit, :integer, default: @limit)
  attr(:options, :any)

  def render(assigns) do
    assigns = assign(assigns, type_opts: @type_opts)

    ~H"""
    <div class="container mx-auto">
      <FilterBox.render
        card_header_text="Browse Course Sections"
        card_body_text=""
        table_model={@table_model}
        show_sort={false}
        show_more_opts={true}
      >
        <div class="flex flex-row justify-between">
          <TextSearch.render id="text-search" text={@options.text_search} />

          <.button variant={:primary} href={~p"/admin/sections/create"}>
            New Section
          </.button>
        </div>

        <:extra_opts>
          <Check.render checked={@options.active_today} click="active_today">
            <span class="ml-2">Active (start/end dates include today)</span>
          </Check.render>

          <form phx-change="change_type" class="d-flex">
            <select name="type" id="select_type" class="custom-select mx-3" style="width: 120px;">
              <option value="" selected>Type</option>
              <option
                :for={type_opt <- @type_opts}
                value={type_opt}
                selected={@options.filter_type == type_opt}
              >
                <%= humanize_type_opt(type_opt) %>
              </option>
            </select>
          </form>

          <form phx-change="change_status" class="d-flex">
            <select name="status" id="select_status" class="custom-select" style="width: 120px;">
              <option value="" selected>Status</option>
              <option
                :for={status_opt <- Ecto.Enum.values(Section, :status)}
                value={status_opt}
                selected={@options.filter_status == status_opt}
              >
                <%= Phoenix.Naming.humanize(status_opt) %>
              </option>
            </select>
          </form>
        </:extra_opts>
      </FilterBox.render>

      <div class="mb-5" />

      <div class="sections-table">
        <PagedTable.render
          filter={@options.text_search}
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
        />
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
    do:
      delegate_to(
        {event, params, socket, &__MODULE__.patch_with/2},
        [&TextSearch.handle_delegated/4, &PagedTable.handle_delegated/4]
      )

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
