defmodule OliWeb.Projects.PublishChangesTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(changes) do
    column_specs = [
      %ColumnSpec{
        name: :title,
        label: "Title",
        td_class: "text-center"
      },
      %ColumnSpec{
        name: :type,
        label: "Change Type",
        td_class: "text-center",
        render_fn: &__MODULE__.render_type/3
      },
      %ColumnSpec{
        name: :is_structural,
        label: "Change Categorization",
        td_class: "text-center",
        render_fn: &__MODULE__.render_structural/3
      }
    ]

    SortableTableModel.new(
      rows: changes,
      column_specs: column_specs,
      event_suffix: "publish_changes",
      id_field: [:id]
    )
  end

  def render_type(assigns, change, _) do
    assigns = Map.merge(assigns, %{type: change.type})

    ~H"""
    <span class={"badge badge-#{@type} mr-2"}><%= @type %></span>
    """
  end

  def render_structural(assigns, revision, _) do
    assigns = Map.merge(assigns, %{is_structural: revision.is_structural})

    ~H"""
    <div data-is-structural={if @is_structural, do: "true", else: "false"}>
      <span class={if @is_structural, do: "font-bold", else: "font-light"}>
        <%= if @is_structural, do: "Structural", else: "Non-structural" %>
      </span>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
