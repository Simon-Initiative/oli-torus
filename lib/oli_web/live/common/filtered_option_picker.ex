defmodule OliWeb.Live.Common.FilteredOptionPicker do
  @moduledoc """
  Generic paginated option picker with configurable single or multiple selection.
  """

  use OliWeb, :html

  alias OliWeb.Common.PagedTable
  alias OliWeb.Live.Common.FilteredOptionPicker.TableModel

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :label, :string, required: true
  attr :description, :string, default: nil
  attr :options, :list, required: true
  attr :filter, :any, required: true
  attr :value_key, :atom, default: :value
  attr :label_key, :atom, default: :label
  attr :description_key, :atom, default: nil
  attr :position_key, :atom, default: nil
  attr :selection_mode, :atom, values: [:single, :multiple], default: :single
  attr :selected_values, :list, default: []
  attr :page, :integer, default: 1
  attr :page_size, :integer, default: 8
  attr :on_toggle, :string, required: true
  attr :on_page, :string, required: true
  attr :on_select, :string, required: true
  attr :on_cancel, :string, required: true

  def filtered_option_picker(assigns) do
    filtered_options = Enum.filter(assigns.options, assigns.filter)
    page_count = max(ceil(length(filtered_options) / assigns.page_size), 1)
    page = min(max(assigns.page, 1), page_count)

    assigns =
      assigns
      |> assign(:filtered_options, filtered_options)
      |> assign(:page_count, page_count)
      |> assign(:page, page)
      |> assign(:offset, (page - 1) * assigns.page_size)

    page_options =
      filtered_options
      |> Enum.slice(assigns.offset, assigns.page_size)
      |> Enum.map(fn option ->
        %{
          value: Map.fetch!(option, assigns.value_key),
          label: Map.fetch!(option, assigns.label_key),
          description: option_description(option, assigns.description_key),
          position: option_position(option, assigns.position_key)
        }
      end)

    {:ok, table_model} = TableModel.new(page_options, assigns.selected_values, assigns.label)
    assigns = assign(assigns, :table_model, table_model)

    ~H"""
    <OliWeb.Components.Modal.modal
      id={@id}
      show={true}
      header_level={2}
      wrapper_class="w-full max-w-2xl p-4"
      on_cancel={Phoenix.LiveView.JS.push(@on_cancel)}
    >
      <:title>{@title}</:title>
      <p :if={@description} class="mb-4 text-sm text-gray-600 dark:text-gray-300">
        {@description}
      </p>
      <div id={"#{@id}-table"}>
        <PagedTable.render
          total_count={length(@filtered_options)}
          limit={@page_size}
          offset={@offset}
          table_model={@table_model}
          allow_selection={true}
          sort=""
          page_change={@on_page}
          selection_change={@on_toggle}
          show_top_paging={false}
          show_bottom_paging={true}
          render_top_info={false}
          no_records_message="No matching options are available."
        />
      </div>
      <div class="mt-4 flex justify-end gap-2">
        <button type="button" class="btn btn-link" phx-click={@on_cancel}>Cancel</button>
        <button
          type="button"
          class="btn btn-primary"
          phx-click={@on_select}
          disabled={@selected_values == []}
        >
          Select
        </button>
      </div>
    </OliWeb.Components.Modal.modal>
    """
  end

  defp option_description(_option, nil), do: nil
  defp option_description(option, key), do: Map.get(option, key)
  defp option_position(_option, nil), do: nil
  defp option_position(option, key), do: Map.get(option, key)
end

defmodule OliWeb.Live.Common.FilteredOptionPicker.TableModel do
  @moduledoc false

  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(options, selected_values, label) do
    rows =
      Enum.map(options, fn option ->
        value = to_string(Map.fetch!(option, :value))

        %{
          value: value,
          label: Map.fetch!(option, :label),
          description: Map.get(option, :description),
          position: Map.get(option, :position),
          selected: value in selected_values
        }
      end)

    column_specs =
      [
        %ColumnSpec{
          name: :selection,
          label: "",
          render_fn: &render_selection/3,
          sortable: false,
          th_class: "w-12",
          td_class: "w-12"
        }
      ] ++
        position_column(rows) ++
        [
          %ColumnSpec{
            name: :label,
            label: label,
            render_fn: &render_option/3,
            sortable: false
          }
        ]

    SortableTableModel.new(
      rows: rows,
      column_specs: column_specs,
      event_suffix: "",
      id_field: :value
    )
  end

  defp position_column(rows) do
    case Enum.any?(rows, &(not is_nil(&1.position))) do
      true ->
        [
          %ColumnSpec{
            name: :position,
            label: "Position",
            sortable: false,
            th_class: "w-20",
            td_class: "w-20"
          }
        ]

      false ->
        []
    end
  end

  defp render_selection(assigns, row, _column_spec) do
    assigns = Map.put(assigns, :row, row)

    ~H"""
    <input
      type="checkbox"
      checked={@row.selected}
      tabindex="-1"
      aria-hidden="true"
      class="pointer-events-none h-5 w-5 rounded-[3px] border-2 border-Border-border-default bg-Surface-surface-background"
    />
    """
  end

  defp render_option(assigns, row, _column_spec) do
    assigns = Map.put(assigns, :row, row)

    ~H"""
    <div class="min-w-0 max-w-xl">
      <div class="font-semibold text-gray-900 dark:text-gray-100">{@row.label}</div>
      <div
        :if={@row.description}
        class="truncate text-sm text-gray-600 dark:text-gray-300"
        title={@row.description}
      >
        {@row.description}
      </div>
    </div>
    """
  end
end
