defmodule OliWeb.Common.SortableTable.Table do
  use Surface.Component

  alias OliWeb.Common.Table.ColumnSpec

  prop(model, :struct, required: true)
  prop(sort, :event, required: true)
  prop(select, :event)
  prop(additional_table_class, :string, default: "table-sm")

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
    <th
      class={"#{column_spec.th_class} border-b border-r p-2 bg-gray-100 #{if column_spec.sortable, do: "cursor-pointer"}"}
      :on-click={if column_spec.sortable, do: @sort, else: nil}
      phx-value-sort_by={column_spec.name}
      data-sortable={if column_spec.sortable == false, do: "false", else: "true"}
      data-sort-column={if @model.sort_by_spec == column_spec, do: "true", else: "false"}
      data-sort-order={if @model.sort_by_spec == column_spec, do: to_string(@model.sort_order || :desc), else: "desc"}
    >
      {#if column_spec.tooltip}
        <span id={column_spec.name} title={column_spec.tooltip} phx-hook="TooltipInit">
        {column_spec.label}
        </span>
      {#else}
        {column_spec.label}
      {/if}

      {#if column_spec.sortable}
        <i class={"fas fa-sort-" <> sort_direction_cls} />
      {/if}
    </th>
    """
  end

  defp render_row(assigns, row) do
    row_class =
      if id_field(row, assigns.model) == assigns.model.selected do
        "border-b table-active"
      else
        if assigns.select != nil do
          "border-b selectable"
        else
          "border-b"
        end
      end

    ~F"""
    <tr
      id={id_field(row, @model)}
      class={row_class <> if Map.get(row, :selected) || id_field(row, assigns.model) == assigns.model.selected, do: " bg-delivery-primary-100 shadow-inner dark:bg-gray-700 dark:text-black", else: ""}
      :on-click={@select}
      phx-value-id={id_field(row, @model)}
    >
      {#for column_spec <- @model.column_specs}
        <td class={"#{column_spec.td_class} border-r p-2"}>
          <div class={if Map.get(@model.data, :fade_data, false), do: "fade-text", else: ""}>
            {#if is_nil(column_spec.render_fn)}
              {ColumnSpec.default_render_fn(column_spec, row)}
            {#else}
              {column_spec.render_fn.(assigns, row, column_spec)}
            {/if}
          </div>
        </td>
      {/for}
    </tr>
    """
  end

  def render(assigns) do
    ~F"""
    <table class={"min-w-full border " <> @additional_table_class}>
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
