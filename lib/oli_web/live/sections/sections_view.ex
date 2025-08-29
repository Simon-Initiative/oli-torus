defmodule OliWeb.Sections.SectionsView do
  use OliWeb, :live_view

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.{Browse, BrowseOptions, Section}

  alias OliWeb.Common.{
    Breadcrumb,
    Check,
    SearchInput,
    StripedPagedTable,
    Params,
    PagingParams
  }

  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Sections.SectionsTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Icons

  @limit 20
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
        %Sorting{direction: :asc, field: :start_date},
        @default_options
      )

    total_count = determine_total(sections)

    {:ok, table_model} =
      SectionsTableModel.new(ctx, sections,
        render_date: :full,
        sort_by_spec: :start_date,
        sort_order: :asc
      )

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
    limit = get_int_param(params, "limit", @limit)

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
        %Paging{offset: offset, limit: limit},
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
       limit: limit,
       options: options
     )}
  end

  def render(assigns) do
    assigns = assign(assigns, type_opts: @type_opts)

    ~H"""
    <div>
      <div class="flex flex-row justify-between items-center px-4">
        <div class="flex flex-col">
          <span class="text-2xl font-bold text-[#353740] dark:text-[#EEEBF5] leading-loose">
            Browse Course Sections
          </span>
          <div class="flex flex-row gap-4 mt-2 items-center">
            <Check.render checked={@options.active_today} click="active_today">
              <span class="justify-start text-[#353740] dark:text-[#EEEBF5] text-base font-normal leading-normal">
                Active (start/end dates include today)
              </span>
            </Check.render>
            <form phx-change="change_type" class="flex flex-row">
              <select name="type" id="select_type" class="custom-select" style="width: 120px;">
                <option value="" selected>Type</option>
                <option
                  :for={type_opt <- @type_opts}
                  value={type_opt}
                  selected={@options.filter_type == type_opt}
                >
                  {humanize_type_opt(type_opt)}
                </option>
              </select>
            </form>
            <form phx-change="change_status" class="flex flex-row">
              <select name="status" id="select_status" class="custom-select" style="width: 120px;">
                <option value="" selected>Status</option>
                <option
                  :for={status_opt <- Ecto.Enum.values(Section, :status)}
                  value={status_opt}
                  selected={@options.filter_status == status_opt}
                >
                  {Phoenix.Naming.humanize(status_opt)}
                </option>
              </select>
            </form>
          </div>
        </div>
        <a
          id="button-new-section"
          class="btn btn-sm rounded-md bg-[#0080FF] text-[#FFFFFF] shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] px-4 py-2"
          href={~p"/admin/sections/create"}
        >
          <i class="fa fa-plus pr-2"></i> New Section
        </a>
      </div>
      <div class="flex w-fit gap-4 p-2 pr-8 mx-4 mt-3 mb-2 shadow-[0px_2px_6.099999904632568px_0px_rgba(0,0,0,0.10)] border border-[#ced1d9] dark:border-[#3B3740] dark:bg-[#000000]">
        <.form for={%{}} phx-change="text_search_change" class="w-56">
          <SearchInput.render id="text-search" name="section_name" text={@options.text_search} />
        </.form>

        <button class="ml-2 text-center text-[#353740] dark:text-[#EEEBF5] text-sm font-normal leading-none flex items-center gap-x-1 opacity-50 hover:cursor-not-allowed">
          <Icons.filter class="stroke-[#353740] dark:stroke-[#EEEBF5]" /> Filter
        </button>

        <button
          class="ml-2 mr-4 text-center text-[#353740] dark:text-[#EEEBF5] text-sm font-normal leading-none flex items-center gap-x-1 hover:text-[#006CD9] dark:hover:text-[#4CA6FF]"
          phx-click="clear_all_filters"
        >
          <Icons.trash /> Clear All Filters
        </button>
      </div>

      <div class="sections-table">
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
    </div>
    """
  end

  def handle_event("active_today", _, socket),
    do: patch_with(socket, %{active_today: !socket.assigns.options.active_today})

  def handle_event("change_status", %{"status" => status}, socket),
    do: patch_with(socket, %{filter_status: status})

  def handle_event("change_type", %{"type" => type}, socket),
    do: patch_with(socket, %{filter_type: type})

  def handle_event("text_search_change", %{"section_name" => section_name}, socket) do
    patch_with(socket, %{text_search: section_name})
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
    new_limit = Params.get_int_param(params, "limit", 20)

    new_offset =
      PagingParams.calculate_new_offset(
        socket.assigns.offset,
        new_limit,
        socket.assigns.total_count
      )

    patch_with(socket, %{limit: new_limit, offset: new_offset})
  end

  def handle_event("clear_all_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/sections")}
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([&StripedPagedTable.handle_delegated/4])
  end

  defp determine_total(sections) do
    case sections do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  def patch_with(socket, changes) do
    {:noreply,
     push_patch(socket,
       to: Routes.live_path(socket, __MODULE__, Map.merge(current_params(socket), changes)),
       replace: true
     )}
  end

  defp current_params(socket) do
    %{
      sort_by: socket.assigns.table_model.sort_by_spec.name,
      sort_order: socket.assigns.table_model.sort_order,
      offset: socket.assigns.offset,
      limit: socket.assigns.limit,
      active_today: socket.assigns.options.active_today,
      filter_status: socket.assigns.options.filter_status,
      filter_type: socket.assigns.options.filter_type,
      text_search: socket.assigns.options.text_search
    }
  end

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(_), do: :asc

  defp humanize_type_opt(:open), do: "DD"
  defp humanize_type_opt(:lms), do: "LTI"
end
