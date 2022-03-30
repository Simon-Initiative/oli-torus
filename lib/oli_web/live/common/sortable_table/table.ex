defmodule OliWeb.Common.SortableTable.Table do
  use Surface.Component

  alias OliWeb.Common.Table.ColumnSpec

  prop model, :struct, required: true
  prop sort, :event, required: true
  prop select, :event
  prop additional_table_class, :string, default: "table-sm"

  @spec id_field(any, %{:id_field => any, optional(any) => any}) :: any
  def id_field(row, %{id_field: id_field}) when is_list(id_field) do
    id_field
    |> Enum.reduce("", fn field, acc ->
      cond do
        is_atom(field) ->
          "#{acc}-#{Map.get(row, field)}"

        is_binary(field) ->
          "#{acc}-#{field}"

        true ->
          acc
      end
    end)
    |> String.trim("-")
  end

  def id_field(row, %{id_field: id_field}) do
    Map.get(row, id_field)
  end

  defp render_th(assigns, column_spec) do
    sort_direction_cls =
      case assigns.model.sort_order do
        :asc -> "up"
        _ -> "down"
      end

    ~F"""
    <th style="cursor: pointer;" :on-click={@sort} phx-value-sort_by={column_spec.name}>
      {column_spec.label}
      {#if @model.sort_by_spec == column_spec}
        <i class={"fas fa-sort-" <> sort_direction_cls}></i>
      {/if}
    </th>
    """
  end

  defp render_row(assigns, row) do
    row_class =
      if id_field(row, assigns.model) == assigns.model.selected do
        "table-active"
      else
        ""
      end

    ~F"""
    <tr id={id_field(row, @model)} class={row_class} :on-click={@select} phx-value-id={id_field(row, @model)}>
    {#for column_spec <- @model.column_specs}
      <td>
      {#if is_nil(column_spec.render_fn)}
        {ColumnSpec.default_render_fn(column_spec, row)}
      {#else}
        {column_spec.render_fn.(assigns, row, column_spec)}
      {/if}
      </td>
    {/for}
    </tr>
    """
  end

  def render(assigns) do
    ~F"""
    <table class={"table table-striped table-bordered " <> @additional_table_class}>
      <thead>
        <tr>
        {#for column_spec <- @model.column_specs}
          {render_th(with_data(assigns, @model.data), column_spec)}
        {/for}
        </tr>
      </thead>
      <tbody>
      {#for row <- @model.rows}
        {render_row(with_data(assigns, @model.data), row)}
      {/for}
      </tbody>
    </table>
    """
  end

  defp with_data(assigns, data) do
    Map.merge(assigns, data)
  end
end
