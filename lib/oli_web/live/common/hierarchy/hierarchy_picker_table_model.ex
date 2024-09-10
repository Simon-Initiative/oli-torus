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
      id_field: [:id]
    )
  end

  def render_child(
        %{
          selection: selection,
          preselected: preselected,
          selected_publication: pub
        } = assigns,
        child
      ) do
    click_handler =
      if {pub.id, child.revision.resource_id} in preselected do
        []
      else
        ["phx-click": "HierarchyPicker.select", "phx-value-uuid": child.uuid]
      end

    assigns =
      Map.merge(assigns, %{
        child: child,
        maybe_checked: maybe_checked(selection, pub.id, child.revision.resource_id),
        maybe_preselected: maybe_preselected(preselected, pub.id, child.revision.resource_id),
        click_handler: click_handler
      })

    ~H"""
    <input
      id={"hierarchy_item_#{ @child.uuid}"}
      {@click_handler}
      type="checkbox"
      {@maybe_checked}
      {@maybe_preselected}
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

  defp maybe_preselected(preselected, pub_id, resource_id) do
    if {pub_id, resource_id} in preselected do
      [checked: true, disabled: true]
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
    <%= @title %>
    """
  end

  def custom_render(assigns, data, %ColumnSpec{name: :graded}) do
    assigns = Map.merge(assigns, %{graded: data.revision.graded})

    ~H"""
    <%= if @graded, do: "Scored", else: "Practice" %>
    """
  end

  def custom_render(assigns, data, %ColumnSpec{name: :updated_at}) do
    assigns = Map.merge(assigns, %{updated_at: data.revision.updated_at})

    ~H"""
    <%= OliWeb.Common.FormatDateTime.format_datetime(@updated_at, show_timezone: false) %>
    """
  end

  def custom_render(assigns, data, %ColumnSpec{name: :publication_date}) do
    assigns = Map.merge(assigns, %{publication_date: data.revision.publication_date})

    ~H"""
    <%= OliWeb.Common.FormatDateTime.format_datetime(@publication_date, show_timezone: false) %>
    """
  end
end
