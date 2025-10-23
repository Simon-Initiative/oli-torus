defmodule OliWeb.Common.Table.SortableTableModel do
  @moduledoc """
  The model for the sortable table LiveComponent.

  The model consists of the `rows` that the table will display.  This must be in the form of an enumeration of
  either maps or structs.

  The `column_specs` are the specifications the columns that the table will render. This does not need to be a
  one-to-one mapping with the attributes present in the rows, and in fact is designed to allow omitting
  columns and implementing derived columns.

  The `selected` item stores the currently selected item - if there is one. A client LiveView can simply choose
  to ignore `selected` events, thus effectively leaving that sortable table with rows that cannot be selected.

  The `sort_by_spec` and `sort_order` attributes power the sorting of the table.  The `sort_by_spec` is
  a reference to the current column that the rows are sorted by.  Given that column specs provide the ability to
  provide an arbitrary sort function to use, a complex sorting implementation where primary, secondary, and
  even tertiary columns can contribute to sort order.  The `sort_by_spec` cannot be nil.

  The `event_suffix` is a string suffix to append to the event names that the table component will dispatch. This
  is used to allow a parent LiveView to differentiate between multiple tables in situations where multiple tables
  exist in the LiveView.  This suffix is also appended to URI parameter names when the attributes of a sortable
  table model are placed in the browser URL for live navigation.

  The `id_field` is the field name from the row items that uniquely identifies a row item.  This will be used
  when emitting events related to a particular row item.
  """
  use Phoenix.Component

  alias OliWeb.Common.Table.ColumnSpec

  # the items to display
  defstruct rows: [],
            # the columns to display
            column_specs: [],
            # the selected row
            selected: nil,
            # the column that is being sorted by
            sort_by_spec: nil,
            # the sort order, :asc or :desc
            sort_order: :asc,
            event_suffix: "",
            # the field used to identify uniquely a row item
            id_field: nil,

            # optional extra data a view can push down to custom sorts or renderers that will be merged with
            # table assigns
            data: %{}

  def new(
        rows: rows,
        column_specs: column_specs,
        event_suffix: event_suffix,
        id_field: id_field
      ),
      do:
        new(
          rows: rows,
          column_specs: column_specs,
          event_suffix: event_suffix,
          id_field: id_field,
          data: %{}
        )

  def new(
        rows: rows,
        column_specs: column_specs,
        event_suffix: event_suffix,
        id_field: id_field,
        data: data
      ) do
    model =
      %__MODULE__{
        rows: rows,
        column_specs: column_specs,
        event_suffix: event_suffix,
        id_field: id_field,
        sort_by_spec: hd(column_specs),
        data: data
      }
      |> sort

    {:ok, model}
  end

  def new(
        rows: rows,
        column_specs: column_specs,
        event_suffix: event_suffix,
        id_field: id_field,
        sort_by_spec: sort_by_spec,
        sort_order: sort_order
      ),
      do:
        new(
          rows: rows,
          column_specs: column_specs,
          event_suffix: event_suffix,
          id_field: id_field,
          sort_by_spec: sort_by_spec,
          sort_order: sort_order,
          data: %{}
        )

  def new(
        rows: rows,
        column_specs: column_specs,
        event_suffix: event_suffix,
        id_field: id_field,
        sort_by_spec: sort_by_spec,
        sort_order: sort_order,
        data: data
      ) do
    model =
      %__MODULE__{
        rows: rows,
        column_specs: column_specs,
        event_suffix: event_suffix,
        id_field: id_field,
        sort_by_spec: sort_by_spec,
        sort_order: sort_order,
        data: data
      }
      |> sort

    {:ok, model}
  end

  def update_selection(%__MODULE__{rows: rows, id_field: id_field} = struct, selected_id) do
    Map.put(
      struct,
      :selected,
      Enum.find(rows, fn row -> Map.get(row, id_field) == selected_id end)
    )
  end

  def update_sort_params(%__MODULE__{sort_order: sort_order} = struct, column_name) do
    current_spec_name = struct.sort_by_spec.name

    case Enum.find(struct.column_specs, fn spec -> spec.name == column_name end) do
      %{name: ^current_spec_name} ->
        Map.put(
          struct,
          :sort_order,
          if sort_order == :asc do
            :desc
          else
            :asc
          end
        )

      spec ->
        Map.put(struct, :sort_by_spec, spec)
    end
  end

  def update_sort_params_and_sort(%__MODULE__{} = struct, column_name) do
    update_sort_params(struct, column_name)
    |> sort
  end

  def sort(%__MODULE__{rows: rows, sort_by_spec: sort_by_spec, sort_order: sort_order} = struct) do
    sorted =
      case sort_by_spec.sort_fn do
        nil ->
          Enum.sort(rows, ColumnSpec.default_sort_fn(sort_order, sort_by_spec))

        func ->
          {mapper, sorter} = func.(sort_order, sort_by_spec)
          Enum.sort_by(rows, mapper, sorter)
      end

    struct
    |> Map.put(:rows, sorted)
  end

  def to_params(%__MODULE__{} = struct) do
    %{}
    |> Map.put("sort_by" <> struct.event_suffix, struct.sort_by_spec.name)
    |> Map.put("sort_order" <> struct.event_suffix, struct.sort_order)
  end

  def update_from_params(%__MODULE__{} = struct, params) do
    column_names =
      Enum.reduce(struct.column_specs, %{}, fn spec, m ->
        case spec.name do
          atom when is_atom(atom) -> Map.put(m, Atom.to_string(spec.name), spec)
          _ -> Map.put(m, spec.name, spec)
        end
      end)

    sort_by =
      case Map.get(column_names, params["sort_by" <> struct.event_suffix]) do
        nil -> struct.sort_by_spec
        spec -> spec
      end

    sort_order =
      case params["sort_order" <> struct.event_suffix] do
        sort_order when sort_order in ~w(asc desc) -> String.to_existing_atom(sort_order)
        _ -> struct.sort_order
      end

    selected =
      case params["selected" <> struct.event_suffix] do
        nil -> nil
        id -> id
      end

    Map.put(struct, :sort_by_spec, sort_by)
    |> Map.put(:sort_order, sort_order)
    |> update_selection(selected)
    |> sort
  end

  def determine_total(entities) do
    case entities do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  def render_link_column(assigns, label, route_path, class \\ "") do
    assigns = Map.merge(assigns, %{label: label, route_path: route_path, class: class})

    ~H"""
    <.link href={@route_path} class={@class}>
      {@label}
    </.link>
    """
  end

  def render_span_column(assigns, text, class \\ "") do
    assigns = Map.merge(assigns, %{text: text, class: class})

    ~H"""
    <span class={@class}>{@text}</span>
    """
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
