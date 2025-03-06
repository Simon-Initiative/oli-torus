defmodule OliWeb.Certificates.Components.CertificatesIssuedTab do
  use OliWeb, :live_component
  use OliWeb, :verified_routes

  alias OliWeb.Common.PagedTable
  alias OliWeb.Common.Params
  alias OliWeb.Common.TextSearch
  alias OliWeb.Icons

  @sort_by_directions ~w(asc desc)a
  @sort_by_fields ~w(recipient issued_at issuer)a
  @allowed_url_params ~w(active_tab sort_by direction limit offset text_search)

  @limit 25
  @offset 0
  @default_values %{
    text_search: nil,
    paging: %{limit: @limit, offset: @offset},
    sorting: %{field: :recipient, direction: :asc}
  }

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-12 w-full">
      <div id="certificates_issued-table" class="col-span-12">
        <div class="mb-5 flex justify-between">
          <TextSearch.render
            id="text-search"
            text={@params["text_search"]}
            event_target={@myself}
            placeholder="Search credentials issued..."
            class="w-[500px]"
          />
          <a
            :if={!@read_only}
            role="export"
            href={~p"/authoring/products/#{assigns.section_slug}/downloads/granted_certificates"}
            class="flex items-center justify-center gap-x-2"
          >
            <Icons.download /> Download CSV
          </a>
        </div>
        <PagedTable.render
          additional_row_class="bg-white dark:bg-black text-[#737373]"
          page_change={JS.push("paged_table_page_change", target: @myself)}
          sort={JS.push("paged_table_sort", target: @myself)}
          total_count={determine_total(@table_model.rows)}
          allow_selection={false}
          limit={@params["limit"]}
          offset={@params["offset"]}
          table_model={@table_model}
          show_top_paging={false}
          show_bottom_paging={true}
          render_top_info={false}
          render_bottom_info={true}
        />
      </div>
    </div>
    """
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    params = %{
      socket.assigns.params
      | "limit" => String.to_integer(limit),
        "offset" => String.to_integer(offset)
    }

    socket = assign(socket, params: params)

    {section_slug, project, route_name} = extract_common_assigns(socket)

    params = Map.take(params, @allowed_url_params)
    path = select_path(route_name, project, section_slug, params)

    {:noreply, push_patch(socket, to: path)}
  end

  def handle_event("paged_table_sort", %{"sort_by" => sort_by}, socket) do
    params = Map.put(socket.assigns.params, "sort_by", String.to_existing_atom(sort_by))

    new_direction =
      case socket.assigns.params["direction"] do
        :asc -> :desc
        :desc -> :asc
      end

    params = Map.put(params, "direction", new_direction)
    socket = assign(socket, params: params)

    {section_slug, project, route_name} = extract_common_assigns(socket)

    params = Map.take(params, @allowed_url_params)
    path = select_path(route_name, project, section_slug, params)

    {:noreply, push_patch(socket, to: path)}
  end

  def handle_event("text_search_change", %{"value" => text_search}, socket) do
    params = Map.put(socket.assigns.params, "text_search", text_search)
    socket = assign(socket, params: params)

    {section_slug, project, route_name} = extract_common_assigns(socket)

    params = Map.take(params, @allowed_url_params)
    path = select_path(route_name, project, section_slug, params)

    {:noreply, push_patch(socket, to: path)}
  end

  def handle_event("text_search_reset", _params, socket) do
    params = Map.put(socket.assigns.params, "text_search", nil)

    {section_slug, project, route_name} = extract_common_assigns(socket)

    params = Map.take(params, @allowed_url_params -- ["text_search"])
    path = select_path(route_name, project, section_slug, params)

    {:noreply, push_patch(socket, to: path)}
  end

  defp extract_common_assigns(socket) do
    section_slug = socket.assigns[:section_slug]
    project = socket.assigns[:project]
    route_name = socket.assigns[:route_name]
    {section_slug, project, route_name}
  end

  def select_path(:authoring, _project, section_slug, params) do
    ~p"/authoring/products/#{section_slug}/certificate_settings?#{params}"
  end

  def select_path(:workspaces, project, section_slug, params) do
    ~p"/workspaces/course_author/#{project.slug}/products/#{section_slug}/certificate_settings?#{params}"
  end

  def select_path(:delivery, _project, section_slug, params) do
    ~p"/sections/#{section_slug}/certificate_settings?#{params}"
  end

  def decode_params(params) do
    text_search = Params.get_param(params, "text_search", @default_values.text_search)
    limit = Params.get_int_param(params, "limit", @default_values.paging.limit)
    offset = Params.get_int_param(params, "offset", @default_values.paging.offset)

    default_sorting_field = @default_values.sorting.field

    sort_by = Params.get_atom_param(params, "sort_by", @sort_by_fields, default_sorting_field)

    default_direction = @default_values.sorting.direction

    direction =
      Params.get_atom_param(params, "direction", @sort_by_directions, default_direction)

    new_params = %{
      "text_search" => text_search,
      "limit" => limit,
      "offset" => offset,
      "sort_by" => sort_by,
      "direction" => direction
    }

    Map.merge(params, new_params)
  end

  defp determine_total(rows) do
    case(rows) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end
end
