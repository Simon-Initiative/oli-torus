defmodule OliWeb.Common.Hierarchy.HierarchyPicker.TableModel do
  use Phoenix.Component
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(pages) do
    column_specs = [
      %ColumnSpec{
        name: :id,
        render_fn: &__MODULE__.custom_render/3,
        th_class: "pl-2",
        sortable: false
      },
      %ColumnSpec{
        name: :title,
        label: "Title",
        render_fn: &__MODULE__.custom_render/3,
        th_class: "pl-2"
      },
      %ColumnSpec{
        name: :graded,
        label: "Page type",
        render_fn: &__MODULE__.custom_render/3,
        th_class: "pl-2"
      },
      %ColumnSpec{
        name: :updated_at,
        label: "Updated at",
        render_fn: &__MODULE__.custom_render/3,
        th_class: "pl-2"
      },
      %ColumnSpec{
        name: :publication_date,
        label: "Published on",
        render_fn: &__MODULE__.custom_render/3,
        th_class: "pl-2 text-right",
        td_class: "text-right"
      }
    ]

    SortableTableModel.new(
      rows: pages,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:uuid]
    )
  end

  def render_child(%{selection: selection, selected_publication: pub} = assigns, child) do
    assigns =
      Map.merge(assigns, %{
        child: child,
        maybe_checked: maybe_checked(selection, pub.id, child.revision.resource_id)
      })

    ~H"""
    <input
      id={"hierarchy_item_#{@child.uuid}"}
      phx-click="HierarchyPicker.select"
      phx-value-uuid={@child.uuid}
      type="checkbox"
      class="w-5 h-5 rounded-[3px] border-2 border-Border-border-default bg-Surface-surface-background cursor-pointer"
      {@maybe_checked}
    />
    """
  end

  defp maybe_checked(selection, pub_id, resource_id) do
    if {pub_id, resource_id} in selection do
      [checked: true]
    else
      []
    end
  end

  def custom_render(assigns, data, %ColumnSpec{name: :id}) do
    render_child(assigns, data)
  end

  def custom_render(assigns, data, %ColumnSpec{name: :title}) do
    assigns = Map.merge(assigns, %{title: data.revision.title})

    ~H"""
    {@title}
    """
  end

  def custom_render(assigns, data, %ColumnSpec{name: :graded}) do
    assigns = Map.merge(assigns, %{graded: data.revision.graded})

    ~H"""
    {if @graded, do: "Scored", else: "Practice"}
    """
  end

  def custom_render(assigns, data, %ColumnSpec{name: :updated_at}) do
    assigns = Map.merge(assigns, %{updated_at: data.revision.updated_at})

    ~H"""
    {OliWeb.Common.FormatDateTime.format_datetime(@updated_at, show_timezone: false)}
    """
  end

  def custom_render(assigns, data, %ColumnSpec{name: :publication_date}) do
    assigns = Map.merge(assigns, %{publication_date: data.revision.publication_date})

    ~H"""
    {OliWeb.Common.FormatDateTime.format_datetime(@publication_date, show_timezone: false)}
    """
  end
end
