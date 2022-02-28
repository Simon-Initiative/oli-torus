defmodule OliWeb.Common.EnrollmentBrowser.EnrollmentPicker do
  use Surface.LiveComponent
  use OliWeb.Common.Modal

  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{TextSearch, PagedTable}
  alias Oli.Delivery.Sections.{EnrollmentBrowseOptions}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Common.EnrollmentBrowser.TableModel
  alias Oli.Delivery.Sections
  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params

  @limit 10
  @default_options %EnrollmentBrowseOptions{
    is_student: true,
    is_instructor: false,
    text_search: ""
  }

  prop section, :any, default: nil
  prop context, :any
  data table_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: @limit
  data options, :any

  def update(assigns, socket) do
    %{total_count: total_count, table_model: table_model} =
      enrollment_assigns(assigns.section, assigns.context)

    {:ok,
     assign(socket,
       id: assigns.id,
       section: assigns.section,
       context: assigns.context,
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

  def render(assigns) do
    ~F"""
    <div id={@id}>

      <TextSearch id="text-search" event_target={"#" <> assigns.id}/>

      <div class="mb-3"/>

      <PagedTable
        sort="paged_table_sort"
        page_change="paged_table_page_change"
        filter={@options.text_search}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}/>
    </div>
    """
  end

  def patch_with(socket, changes) do
    # Take the `changes` map and merge it into the current socket assigns
    # in a way that simulates a URL query params.  This includes converting
    # all keys and values to strings
    params =
      Map.merge(
        %{
          sort_by: socket.assigns.table_model.sort_by_spec.name,
          sort_order: socket.assigns.table_model.sort_order,
          offset: socket.assigns.offset,
          text_search: socket.assigns.options.text_search
        },
        changes
      )
      |> Enum.reduce(%{}, fn {k, v}, m ->
        string_key = Atom.to_string(k)

        string_value =
          case v do
            a when is_atom(a) -> Atom.to_string(a)
            s when is_binary(s) -> s
            v -> Integer.to_string(v)
          end

        Map.put(m, string_key, string_value)
      end)

    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = get_int_param(params, "offset", 0)

    options = %EnrollmentBrowseOptions{
      text_search: get_param(params, "text_search", ""),
      is_student: true,
      is_instructor: false
    }

    enrollments =
      Sections.browse_enrollments(
        socket.assigns.section,
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    table_model = Map.put(table_model, :rows, enrollments)
    total_count = determine_total(enrollments)

    {:noreply,
     assign(socket,
       offset: offset,
       table_model: table_model,
       total_count: total_count,
       options: options
     )}
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end

  def enrollment_assigns(section, context) do
    enrollments =
      Sections.browse_enrollments(
        section,
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :name},
        @default_options
      )

    total_count = determine_total(enrollments)
    {:ok, table_model} = TableModel.new(enrollments, section, context)

    %{total_count: total_count, table_model: table_model}
  end
end
