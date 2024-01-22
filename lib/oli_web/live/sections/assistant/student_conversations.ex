defmodule OliWeb.Sections.Assistant.StudentConversationsLive do
  use OliWeb, :live_view

  alias Oli.Delivery.Sections
  alias Oli.Conversation
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Sections.StudentConversationsTableModel
  alias OliWeb.Common.Params
  alias OliWeb.Common.{PagedTable, SearchInput}

  @default_params %{
    offset: 0,
    limit: 20,
    sort_order: :asc,
    sort_by: :student,
    text_search: nil
  }

  def mount(_params, _session, socket) do
    {:ok, assign(socket, table_model: nil)}
  end

  def handle_params(
        params,
        _,
        socket
      ) do
    params = decode_params(params)

    socket =
      socket
      |> assign(params: params)
      |> assign_new(:students, fn ->
        Conversation.get_students_with_conversation_count(socket.assigns.section.slug)
      end)
      |> assign_new(:resource_titles, fn ->
        Sections.section_resource_titles(socket.assigns.section.slug)
      end)

    {total_count, rows} =
      apply_filters(socket.assigns.students, socket.assigns.resource_titles, params)

    {:ok, table_model} =
      StudentConversationsTableModel.new(rows, socket.assigns.resource_titles)

    table_model =
      Map.merge(table_model, %{
        rows: rows,
        sort_order: params.sort_order
      })
      |> SortableTableModel.update_sort_params(params.sort_by)

    {:noreply,
     assign(socket,
       table_model: table_model,
       total_count: total_count
     )}
  end

  defp apply_filters(students, resource_titles, params) do
    students =
      students
      |> maybe_filter_by_text(params.text_search, resource_titles)
      |> sort_by(params.sort_by, params.sort_order, resource_titles)

    {length(students), students |> Enum.drop(params.offset) |> Enum.take(params.limit)}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto mb-10">
      <.loader if={!@table_model} />
      <div :if={@table_model} class="bg-white shadow-sm dark:bg-gray-800 dark:text-white">
        <div class="flex flex-col space-y-4 lg:space-y-0 lg:flex-row lg:justify-between px-9">
          <h4 class="torus-h4 whitespace-nowrap">Student AI Conversations</h4>

          <div class="flex flex-col">
            <form for="search" phx-change="search_students" class="pb-6 lg:ml-auto lg:pt-7">
              <SearchInput.render
                id="students_search_input"
                name="student_name"
                text={@params.text_search}
              />
            </form>
            <div></div>
          </div>
        </div>

        <PagedTable.render
          table_model={@table_model}
          total_count={@total_count}
          offset={@params.offset}
          limit={@params.limit}
          page_change={JS.push("paged_table_page_change")}
          sort={JS.push("paged_table_sort")}
          additional_table_class="instructor_dashboard_table"
          allow_selection={false}
          show_bottom_paging={false}
          limit_change={JS.push("paged_table_limit_change")}
          show_limit_change={true}
        />
      </div>
    </div>
    """
  end

  def handle_event(
        "search_students",
        %{"student_name" => student_name},
        socket
      ) do
    {:noreply,
     push_patch(socket,
       to:
         route_to(
           socket,
           update_params(socket.assigns.params, %{
             text_search: student_name,
             offset: 0
           })
         )
     )}
  end

  def handle_event(
        "paged_table_page_change",
        %{"limit" => limit, "offset" => offset},
        socket
      ) do
    {:noreply,
     push_patch(socket,
       to:
         route_to(
           socket,
           update_params(socket.assigns.params, %{limit: limit, offset: offset})
         )
     )}
  end

  def handle_event(
        "paged_table_limit_change",
        params,
        %{assigns: %{params: current_params}} = socket
      ) do
    new_limit = Params.get_int_param(params, "limit", 20)

    new_offset =
      OliWeb.Common.PagingParams.calculate_new_offset(
        current_params.offset,
        new_limit,
        socket.assigns.total_count
      )

    {:noreply,
     push_patch(socket,
       to:
         route_to(
           socket,
           update_params(socket.assigns.params, %{limit: new_limit, offset: new_offset})
         )
     )}
  end

  def handle_event(
        "paged_table_sort",
        %{"sort_by" => sort_by} = _params,
        socket
      ) do
    {:noreply,
     push_patch(socket,
       to:
         route_to(
           socket,
           update_params(socket.assigns.params, %{
             sort_by: String.to_existing_atom(sort_by)
           })
         )
     )}
  end

  defp decode_params(params) do
    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      sort_order:
        Params.get_atom_param(
          params,
          "sort_order",
          [:asc, :desc],
          @default_params.sort_order
        ),
      sort_by:
        Params.get_atom_param(
          params,
          "sort_by",
          [
            :student,
            :resource,
            :num_messages
          ],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search)
    }
  end

  defp update_params(
         %{sort_by: current_sort_by, sort_order: current_sort_order} = params,
         %{
           sort_by: new_sort_by
         }
       )
       when current_sort_by == new_sort_by do
    toggled_sort_order = if current_sort_order == :asc, do: :desc, else: :asc
    update_params(params, %{sort_order: toggled_sort_order})
  end

  defp update_params(params, new_param) do
    Map.merge(params, new_param)
  end

  defp route_to(socket, params) do
    Routes.live_path(
      socket,
      __MODULE__,
      socket.assigns.section.slug,
      params
    )
  end

  defp maybe_filter_by_text(rows, nil, _), do: rows
  defp maybe_filter_by_text(rows, "", _), do: rows

  defp maybe_filter_by_text(rows, text_search, resource_titles) do
    Enum.filter(rows, fn row ->
      maybe_contains?(
        maybe_downcase(username_or_guest(row.user)),
        maybe_downcase(text_search)
      ) ||
        maybe_contains?(
          maybe_downcase(Map.get(resource_titles, row.resource_id)),
          maybe_downcase(text_search)
        )
    end)
  end

  defp sort_by(rows, sort_by, sort_order, resource_titles) do
    case sort_by do
      :student ->
        Enum.sort_by(
          rows,
          fn a -> maybe_byte_size(a.user.name) end,
          sort_order
        )

      :resource ->
        Enum.sort_by(
          rows,
          fn a -> Map.get(resource_titles, a.resource_id) |> maybe_downcase end,
          sort_order
        )

      :num_messages ->
        Enum.sort_by(rows, fn a -> a.num_messages end, sort_order)
    end
  end

  defp maybe_byte_size(nil), do: 0
  defp maybe_byte_size(string), do: byte_size(string)

  defp maybe_downcase(nil), do: nil
  defp maybe_downcase(string), do: String.downcase(string)

  defp maybe_contains?(nil, _), do: false
  defp maybe_contains?(_, nil), do: false
  defp maybe_contains?(string, substring), do: String.contains?(string, substring)

  defp username_or_guest(user) do
    case user do
      %{name: nil} -> "Guest"
      %{name: name} -> name
    end
  end
end
