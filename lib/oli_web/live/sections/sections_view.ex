defmodule OliWeb.Sections.SectionsView do
  use OliWeb, :live_view

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.{Browse, BrowseOptions, Section}
  alias Oli.Institutions

  alias OliWeb.Common.{Breadcrumb, Check, SearchInput, StripedPagedTable, Params, PagingParams}

  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Components.FilterPanel
  alias OliWeb.Icons
  alias OliWeb.Sections.SectionsTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Admin.BrowseFilters

  @limit 20
  @min_search_length 3
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
  @status_options [
    {:active, "Active"},
    {:deleted, "Deleted"}
  ]
  @delivery_options [
    {:dd, "DD"},
    {:lti, "LTI"}
  ]
  @requires_payment_options [
    {true, "Yes"},
    {false, "No"}
  ]
  @date_field_options [{"inserted_at", "Created Date"}]
  @filter_fields [:date, :tags, :delivery, :status, :requires_payment, :institution]

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
    author = socket.assigns.current_author
    is_admin = Oli.Accounts.has_admin_role?(author, :content_admin)

    filters = BrowseFilters.default()
    institutions = Institutions.list_institutions()

    sections =
      Browse.browse_sections(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :desc, field: :start_date},
        @default_options
      )

    total_count = determine_total(sections)
    export_filename = "sections-" <> Date.to_iso8601(Date.utc_today()) <> ".csv"

    {:ok, table_model} =
      SectionsTableModel.new(ctx, sections,
        render_date: :full,
        sort_by_spec: :start_date,
        sort_order: :desc,
        search_term: "",
        is_admin: is_admin,
        current_author: author
      )

    {:ok,
     assign(socket,
       breadcrumbs: set_breadcrumbs(),
       author: socket.assigns.current_author,
       sections: sections,
       total_count: total_count,
       table_model: table_model,
       export_filename: export_filename,
       options: @default_options,
       filters: filters,
       text_search_input: "",
       offset: 0,
       limit: @limit,
       status_options: @status_options,
       delivery_options: @delivery_options,
       requires_payment_options: @requires_payment_options,
       institution_options: institutions,
       date_field_options: @date_field_options,
       filter_fields: @filter_fields
     )}
  end

  def handle_params(params, _, socket) do
    table_model = SortableTableModel.update_from_params(socket.assigns.table_model, params)
    offset = get_int_param(params, "offset", 0)
    limit = get_int_param(params, "limit", @limit)

    raw_search = params |> get_param("text_search", "") |> String.trim()
    applied_search = sanitize_search_term(raw_search)

    # Parse filter state from URL params
    filters_state = BrowseFilters.parse(params)
    course_filters = BrowseFilters.to_course_filters(filters_state)

    options = %BrowseOptions{
      text_search: applied_search,
      active_today: get_boolean_param(params, "active_today", false),
      filter_status:
        get_atom_param(params, "filter_status", Ecto.Enum.values(Section, :status), nil) ||
          course_filters.status,
      filter_type:
        get_atom_param(params, "filter_type", @type_opts, nil) || course_filters.delivery,
      institution_id: course_filters.institution_id,
      filter_requires_payment: course_filters.requires_payment,
      filter_tag_ids: course_filters.tag_ids,
      filter_date_from: course_filters.date_from,
      filter_date_to: course_filters.date_to,
      filter_date_field: course_filters.date_field,
      # This view is currently for all root products
      blueprint_id: nil,
      project_id: nil
    }

    sections =
      Browse.browse_sections(
        %Paging{offset: offset, limit: limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    table_model =
      table_model
      |> Map.put(:rows, sections)
      |> Map.update!(:data, &Map.put(&1, :search_term, applied_search))

    total_count = determine_total(sections)

    {:noreply,
     assign(socket,
       offset: offset,
       sections: sections,
       table_model: table_model,
       total_count: total_count,
       limit: limit,
       options: options,
       filters: filters_state,
       text_search_input: raw_search
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="flex flex-row justify-between items-center px-4">
        <span class="text-2xl font-bold text-[#353740] dark:text-[#EEEBF5] leading-loose">
          Browse Course Sections
        </span>
        <a
          id="button-new-section"
          class="btn btn-sm rounded-md bg-[#0080FF] text-[#FFFFFF] shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] px-4 py-2"
          href={~p"/admin/sections/create"}
        >
          <i class="fa fa-plus pr-2"></i> New Section
        </a>
      </div>
      <div class="flex justify-between">
        <div class="flex w-fit gap-4 p-2 pr-8 mx-4 mt-3 mb-2 shadow-[0px_2px_6.099999904632568px_0px_rgba(0,0,0,0.10)] border border-[#ced1d9] dark:border-[#3B3740] dark:bg-[#000000]">
          <.form for={%{}} phx-change="text_search_change" class="w-56">
            <SearchInput.render id="text-search" name="section_name" text={@text_search_input} />
          </.form>

          <Check.render
            id="filter-active-today"
            checked={@options.active_today}
            click="active_today"
            class="text-Text-text-high"
          >
            <span class="text-sm font-normal leading-none">
              Active (start/end dates include today)
            </span>
          </Check.render>

          <.live_component
            module={FilterPanel}
            id="sections-filter-panel"
            parent_pid={self()}
            filters={@filters}
            fields={@filter_fields}
            status_options={@status_options}
            delivery_options={@delivery_options}
            requires_payment_options={@requires_payment_options}
            institution_options={@institution_options}
            date_field_options={@date_field_options}
          />
        </div>
        <a
          role="button"
          class="group mr-4 inline-flex items-center gap-1 text-sm text-Text-text-button font-bold leading-none hover:text-Text-text-button-hover"
          href={~p"/admin/sections/export?#{current_params(assigns)}"}
          download={@export_filename}
        >
          Download CSV
          <Icons.download stroke_class="group-hover:stroke-Text-text-button-hover stroke-Text-text-button" />
        </a>
      </div>

      <div class="sections-table overflow-x-auto">
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

  def handle_info({:filter_panel, :apply, filters}, socket) do
    filter_params = BrowseFilters.to_query_params(filters, as: :atoms)

    # Drop all existing filter keys from current params before merging
    # This ensures cleared filters are properly removed from the URL
    base_params = Map.drop(current_params(socket), BrowseFilters.param_keys(:atoms))

    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           Map.merge(base_params, Map.merge(filter_params, %{offset: 0}))
         ),
       replace: true
     )}
  end

  def handle_info({:filter_panel, :clear}, socket) do
    # Explicitly build params without any filter params to clear them from URL
    params = %{
      sort_by: socket.assigns.table_model.sort_by_spec.name,
      sort_order: socket.assigns.table_model.sort_order,
      offset: 0,
      limit: socket.assigns.limit,
      text_search: socket.assigns.text_search_input
    }

    {:noreply,
     push_patch(socket,
       to: Routes.live_path(socket, __MODULE__, params),
       replace: true
     )}
  end

  def handle_event("text_search_change", %{"section_name" => section_name}, socket) do
    patch_with(socket, %{text_search: String.trim(section_name)})
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

  def handle_event("active_today", _params, socket) do
    patch_with(socket, %{active_today: !socket.assigns.options.active_today})
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

  defp current_params(%Phoenix.LiveView.Socket{} = socket), do: current_params(socket.assigns)

  defp current_params(assigns) do
    base = %{
      sort_by: assigns.table_model.sort_by_spec.name,
      sort_order: assigns.table_model.sort_order,
      offset: assigns.offset,
      limit: assigns.limit,
      text_search: assigns.text_search_input,
      active_today: assigns.options.active_today
    }

    filter_params =
      case Map.get(assigns, :filters) do
        nil -> %{}
        filters -> BrowseFilters.to_query_params(filters, as: :atoms)
      end

    Map.merge(base, filter_params)
  end

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(_), do: :asc

  defp sanitize_search_term(nil), do: ""

  defp sanitize_search_term(search) when is_binary(search) do
    trimmed = String.trim(search)

    cond do
      trimmed == "" -> ""
      String.length(trimmed) < @min_search_length -> ""
      true -> trimmed
    end
  end
end
