defmodule OliWeb.Users.UserEnrolledSections do
  use OliWeb, :live_component

  alias OliWeb.Common.{SearchInput, Params}
  alias OliWeb.Common.SortableTable.StripedTable
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Users.UserEnrolledTableModel
  alias Phoenix.LiveView.JS

  @default_params %{
    offset: 0,
    limit: 10,
    sort_order: :asc,
    sort_by: :title,
    text_search: nil
  }

  def update(
        %{user: user, params: params, ctx: ctx, enrolled_sections: enrolled_sections} = _assigns,
        socket
      ) do
    params = decode_params(params)

    {total_count, rows} = apply_filters(enrolled_sections, params)

    {:ok, table_model} = UserEnrolledTableModel.new(rows, user, ctx)

    table_model =
      Map.merge(table_model, %{
        rows: rows,
        sort_order: params.sort_order,
        sort_by_spec:
          Enum.find(table_model.column_specs, fn col_spec -> col_spec.name == params.sort_by end)
      })

    {:ok,
     assign(socket,
       enrolled_sections: enrolled_sections,
       params: params,
       table_model: table_model,
       total_count: total_count,
       user: user
     )}
  end

  attr(:enrolled_sections, :list, required: true)
  attr(:params, :map, required: true)
  attr(:table_model, :map, required: true)
  attr(:total_count, :integer, required: true)

  def render(assigns) do
    ~H"""
    <div class="flex w-full flex-col gap-y-4">
      <%= if length(@enrolled_sections) > 0 do %>
        <div class="flex w-full items-center">
          <form
            for="search"
            phx-target={@myself}
            phx-change="search_section"
            class="w-56"
          >
            <SearchInput.render
              id="section_search_input"
              name="section_title"
              text={@params.text_search}
            />
          </form>
        </div>

        <%= if @total_count > 0 do %>
          <div
            id="sections-enrolled-table"
            class={[
              "w-full overflow-x-auto",
              if(@total_count > 10, do: "max-h-[570px] overflow-y-auto", else: "")
            ]}
          >
            <StripedTable.render
              model={@table_model}
              sort={JS.push("paged_table_sort", target: @myself)}
              additional_table_class="instructor_dashboard_table table_header_separated w-full"
              sticky_header_offset={0}
            />
          </div>
        <% else %>
          <h6 class="text-center py-4">There are no sections to show</h6>
        <% end %>
      <% else %>
        <h6 class="text-center py-4">User is not enrolled in any course section</h6>
      <% end %>
    </div>
    """
  end

  def handle_event("search_section", %{"section_title" => section_title}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Users.UsersDetailView,
           socket.assigns.user.id,
           update_params(socket.assigns.params, %{text_search: section_title, offset: 0})
         )
     )}
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Users.UsersDetailView,
           socket.assigns.user.id,
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
           OliWeb.Users.UsersDetailView,
           socket.assigns.user.id,
           update_params(socket.assigns.params, %{sort_by: String.to_existing_atom(sort_by)})
         )
     )}
  end

  defp decode_params(params) do
    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      sort_order:
        Params.get_atom_param(params, "sort_order", [:asc, :desc], @default_params.sort_order),
      sort_by:
        Params.get_atom_param(
          params,
          "sort_by",
          [
            :title,
            :enrollment_status,
            :enrollment_role,
            :start_date,
            :end_date,
            :payment_status,
            :last_accessed
          ],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search)
    }
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
    Map.filter(params, fn {key, value} ->
      @default_params[key] != value
    end)
  end

  defp apply_filters(sections, params) do
    sections =
      sections
      |> maybe_filter_by_text(params.text_search)
      |> sort_by(params.sort_by, params.sort_order)

    {length(sections), sections}
  end

  defp sort_by(sections, sort_by, sort_order) do
    case sort_by do
      :title ->
        Enum.sort_by(sections, fn section -> section.title end, sort_order)

      :enrollment_status ->
        Enum.sort_by(sections, fn section -> section.enrollment_status end, sort_order)

      :enrollment_role ->
        Enum.sort_by(sections, fn section -> section.enrollment_role end, sort_order)

      :start_date ->
        sort_by_datetime(sections, :start_date, sort_order)

      :end_date ->
        sort_by_datetime(sections, :end_date, sort_order)

      :payment_status ->
        Enum.sort_by(sections, fn section -> section.payment_status end, sort_order)

      :last_accessed ->
        sort_by_datetime(sections, :last_accessed, sort_order)

      _ ->
        Enum.sort_by(sections, fn section -> section.title end, sort_order)
    end
  end

  defp sort_by_datetime(sections, field, sort_order) do
    {nulls, with_values} =
      Enum.split_with(sections, fn section -> is_nil(Map.get(section, field)) end)

    sorted =
      Enum.sort_by(
        with_values,
        fn section -> Map.get(section, field) end,
        {sort_order, DateTime}
      )

    case sort_order do
      :desc -> nulls ++ sorted
      _ -> sorted ++ nulls
    end
  end

  defp maybe_filter_by_text(sections, nil), do: sections
  defp maybe_filter_by_text(sections, ""), do: sections

  defp maybe_filter_by_text(sections, text_search) do
    sections
    |> Enum.filter(fn section ->
      String.contains?(String.downcase(section.title), String.downcase(text_search))
    end)
  end
end
