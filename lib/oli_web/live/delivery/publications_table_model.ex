defmodule OliWeb.Common.Hierarchy.Publications.TableModel do
  use Phoenix.Component
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(sources) do
    column_specs = [
      %ColumnSpec{
        name: :title,
        label: "ORDER",
        th_class: "hidden",
        render_fn: &__MODULE__.custom_render/3,
        td_class: "pl-0",
        sortable: false
      }
    ]

    SortableTableModel.new(
      rows: sources,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:key],
      data: %{}
    )
  end

  def custom_render(assigns, source, _) do
    assigns = Map.merge(assigns, %{source: source})

    ~H"""
    <div id={"hierarchy_item_#{@source.key}"}>
      <button
        class="btn btn-link ml-1 mr-1 entry-title"
        phx-click="HierarchyPicker.select_publication"
        phx-value-key={@source.key}
      >
        {@source.title}
      </button>
      <span class="ml-2 text-xs text-gray-600">
        {if @source.type == :project, do: "Project", else: "Product/Template"}
      </span>
    </div>
    """
  end
end
