defmodule OliWeb.Sections.AssessmentSettings.SettingsTable do
  use Surface.LiveComponent

  alias OliWeb.Common.{PagedTable, SearchInput}
  alias OliWeb.Sections.AssessmentSettings.SettingsTableModel
  alias OliWeb.Common.Params
  alias Phoenix.LiveView.JS
  alias OliWeb.Router.Helpers, as: Routes

  prop(assessments, :list, required: true)
  prop(params, :map, required: true)
  prop(section_slug, :string, required: true)

  @default_params %{
    offset: 0,
    limit: 10,
    sort_order: :asc,
    sort_by: :assessment,
    text_search: nil
  }

  def update(assigns, socket) do
    params = decode_params(assigns.params)

    {total_count, rows} = apply_filters(assigns.assessments, params)

    {:ok, table_model} = SettingsTableModel.new(rows, assigns.section_slug)

    table_model =
      Map.merge(table_model, %{
        rows: rows,
        sort_order: params.sort_order,
        sort_by_spec:
          Enum.find(table_model.column_specs, fn col_spec -> col_spec.name == params.sort_by end)
      })

    {:ok,
     assign(socket,
       table_model: table_model,
       total_count: total_count,
       params: params,
       section_slug: assigns.section_slug
     )}
  end

  def render(assigns) do
    ~F"""
    <div class="mx-10 mb-10 bg-white shadow-sm">
      <div class="flex flex-col sm:flex-row sm:items-center pr-6 bg-white">
        <div class="flex flex-col pl-9 mr-auto">
          <h4 class="torus-h4">Assessment Settings</h4>
          <p>These are your current assessment settings.</p>
        </div>
        <form for="search" phx-target={@myself} phx-change="search_assessment" class="pb-6 ml-9 sm:pb-0">
          <SearchInput.render
            id="assessments_search_input"
            name="assessment_name"
            text={@params.text_search}
          />
        </form>
      </div>
      <form for="settings_table" phx-target={@myself} phx-change="update_setting">
        <PagedTable
          table_model={@table_model}
          total_count={@total_count}
          offset={@params.offset}
          limit={@params.limit}
          page_change={JS.push("paged_table_page_change", target: @myself)}
          sort={JS.push("paged_table_sort", target: @myself)}
          additional_table_class="instructor_dashboard_table"
          show_bottom_paging={false}
          render_top_info={false}
        />
      </form>
    </div>
    """
  end

  def handle_event("search_assessment", %{"assessment_name" => assessment_name}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Sections.AssessmentSettings.SettingsLive,
           socket.assigns.section_slug,
           :settings,
           :all,
           update_params(socket.assigns.params, %{text_search: assessment_name})
         )
     )}
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Sections.AssessmentSettings.SettingsLive,
           socket.assigns.section_slug,
           :settings,
           :all,
           update_params(socket.assigns.params, %{limit: limit, offset: offset})
         )
     )}
  end

  def handle_event("paged_table_sort", %{"sort_by" => sort_by} = _params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Sections.AssessmentSettings.SettingsLive,
           socket.assigns.section_slug,
           :settings,
           :all,
           update_params(socket.assigns.params, %{sort_by: String.to_existing_atom(sort_by)})
         )
     )}
  end

  def handle_event("update_setting", _params, socket) do
    # TODO update assessment setting
    {:noreply, socket}
  end

  def decode_params(params) do
    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      sort_order:
        Params.get_atom_param(params, "sort_order", [:asc, :desc], @default_params.sort_order),
      sort_by:
        Params.get_atom_param(
          params,
          "sort_by",
          [:assessment],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search)
    }
  end

  defp apply_filters(assessments, params) do
    assessments =
      assessments
      |> maybe_filter_by_text(params.text_search)
      |> sort_by(params.sort_by, params.sort_order)

    {length(assessments), assessments |> Enum.drop(params.offset) |> Enum.take(params.limit)}
  end

  defp maybe_filter_by_text(assessments, nil), do: assessments
  defp maybe_filter_by_text(assessments, ""), do: assessments

  defp maybe_filter_by_text(assessments, text_search) do
    Enum.filter(assessments, fn assessment ->
      String.contains?(
        String.downcase(assessment.name),
        String.downcase(text_search)
      )
    end)
  end

  defp sort_by(assessments, sort_by, sort_order) do
    # TODO set other sort options
    case sort_by do
      :assessment ->
        Enum.sort_by(
          assessments,
          fn assessment ->
            assessment.name
          end,
          sort_order
        )

      _ ->
        Enum.sort_by(
          assessments,
          fn assessment ->
            assessment.name
          end,
          sort_order
        )
    end
  end

  defp update_params(%{sort_by: current_sort_by, sort_order: current_sort_order} = params, %{
         sort_by: new_sort_by
       })
       when current_sort_by == new_sort_by do
    toggled_sort_order = if current_sort_order == :asc, do: :desc, else: :asc
    update_params(params, %{sort_order: toggled_sort_order})
  end

  defp update_params(params, new_param) do
    Map.merge(params, new_param)
    |> purge_default_params()
  end

  defp purge_default_params(params) do
    # there is no need to add a param to the url if its value is equal to the default one
    Map.filter(params, fn {key, value} ->
      @default_params[key] != value
    end)
  end
end
