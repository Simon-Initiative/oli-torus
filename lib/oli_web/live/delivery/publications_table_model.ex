defmodule OliWeb.Common.Hierarchy.Publications.TableModel do
  use Phoenix.Component
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(publications) do
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
      rows: publications,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{}
    )
  end

  def custom_render(assigns, publication, _) do
    assigns = Map.merge(assigns, %{publication: publication})

    ~H"""
    <div id={"hierarchy_item_#{@publication.id}"}>
      <button
        class="btn btn-link ml-1 mr-1 entry-title"
        phx-click="HierarchyPicker.select_publication"
        phx-value-id={@publication.id}
      >
        {@publication.project.title}
      </button>
    </div>
    """
  end
end
