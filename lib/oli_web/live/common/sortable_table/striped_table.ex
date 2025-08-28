defmodule OliWeb.Common.SortableTable.StripedTable do
  use Phoenix.Component

  require Integer

  alias OliWeb.Common.Table.ColumnSpec

  @spec id_field(any, %{:id_field => any, optional(any) => any}) :: any
  def id_field(row, %{id_field: id_field}) when is_list(id_field) do
    id_field
    |> Enum.reduce("", fn
      field, acc when is_atom(field) ->
        "#{acc}-#{Map.get(row, field)}"

      field, acc when is_binary(field) ->
        "#{acc}-#{field}"

      _field, acc ->
        acc
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

    assigns =
      Map.merge(assigns, %{sort_direction_cls: sort_direction_cls, column_spec: column_spec})

    ~H"""
    <th
      class={"#{@column_spec.th_class} pl-2.5 border-b border-r p-2 bg-gray-100 font-semibold #{if @column_spec.sortable, do: "cursor-pointer"}"}
      phx-click={if @column_spec.sortable, do: @sort, else: nil}
      phx-value-sort_by={@column_spec.name}
      data-sortable={if @column_spec.sortable == false, do: "false", else: "true"}
      data-sort-column={if @model.sort_by_spec == @column_spec, do: "true", else: "false"}
      data-sort-order={
        if @model.sort_by_spec == @column_spec,
          do: to_string(@model.sort_order || :desc),
          else: "desc"
      }
    >
      <div class="flex items-center gap-1">
        <%= if @column_spec.tooltip do %>
          <span id={@column_spec.name} title={@column_spec.tooltip} phx-hook="TooltipInit">
            {@column_spec.label}
          </span>
        <% else %>
          {@column_spec.label}
        <% end %>

        <%= if @column_spec.sortable do %>
          <OliWeb.Icons.chevron_down
            width="16"
            height="16"
            class={"inline fill-black dark:fill-white " <> if @sort_direction_cls == "up", do: "", else: "rotate-180 "}
          />
        <% end %>
      </div>
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

    row_class = row_class <> " #{assigns[:additional_row_class]}"

    row_id =
      if assigns.model.data[:view_type] == :objectives_instructor_dashboard,
        do: "row_#{row.resource_id}_#{assigns.index}",
        else: id_field(row, assigns.model)

    assigns = Map.merge(assigns, %{row: row, row_class: row_class, row_id: row_id})

    ~H"""
    <tr
      id={@row_id}
      data-row-id={@row_id}
      class={@row_class <> " hover:bg-Table-table-hover" <>
    if Map.get(@row, :selected) || id_field(@row, @model) == @model.selected,
      do: " bg-delivery-primary-100 shadow-inner dark:bg-gray-700 dark:text-black",
      else: ""}
      aria-selected={if Map.get(@row, :selected), do: "true", else: "false"}
      phx-click={@select}
      phx-value-id={id_field(@row, @model)}
    >
      <%= for column_spec <- @model.column_specs do %>
        <td class={"#{column_spec.td_class} border-r p-2 pl-2.5"}>
          <div class={if Map.get(@model.data, :fade_data, false), do: "fade-text", else: ""}>
            <%= if is_nil(column_spec.render_fn) do %>
              {ColumnSpec.default_render_fn(column_spec, @row)}
            <% else %>
              {column_spec.render_fn.(
                with_data(
                  %{
                    model: @model,
                    sort: @sort,
                    select: @select,
                    additional_table_class: @additional_table_class
                  },
                  @model.data
                ),
                @row,
                column_spec
              )}
            <% end %>
          </div>
        </td>
      <% end %>
    </tr>
    """
  end

  attr :model, :map, required: true
  attr :sort, :string, required: true
  attr :select, :string, default: ""
  attr :additional_table_class, :string, default: "table-sm"
  attr :additional_row_class, :string, default: ""

  def render(assigns) do
    ~H"""
    <table class={"min-w-full border " <> @additional_table_class}>
      <thead class="sticky top-0 bg-white dark:bg-[#000000] z-10">
        <tr>
          <%= for column_spec <- @model.column_specs do %>
            {render_th(
              with_data(
                %{
                  model: @model,
                  sort: @sort,
                  select: @select,
                  additional_table_class: @additional_table_class
                },
                @model.data
              ),
              column_spec
            )}
          <% end %>
        </tr>
      </thead>
      <tbody>
        <%= for {row, index} <- Enum.with_index(@model.rows) do %>
          {render_row(
            with_data(
              %{
                model: @model,
                sort: @sort,
                select: @select,
                additional_table_class: @additional_table_class,
                additional_row_class:
                  if(Integer.is_even(index),
                    do: "bg-Table-table-row-1 ",
                    else: "bg-Table-table-row-2 "
                  ) <> @additional_row_class,
                index: index
              },
              @model.data
            ),
            row
          )}

          <%= if @model.data[:expandable_rows] do %>
            {render_details_row(
              with_data(
                %{
                  model: @model,
                  sort: @sort,
                  select: @select,
                  additional_table_class: @additional_table_class,
                  index: index
                },
                @model.data
              ),
              row
            )}
          <% end %>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp with_data(assigns, data) do
    Map.merge(assigns, data)
  end

  defp render_details_row(assigns, row) do
    col_span = length(assigns.model.column_specs)
    unique_id = "row_#{row.resource_id}_#{assigns.index}"

    assigns = Map.merge(assigns, %{col_span: col_span, unique_id: unique_id})

    ~H"""
    <tr id={"details-#{@unique_id}"} class="hidden">
      <td colspan={@col_span} class="bg-gray-50 dark:bg-gray-900 p-4">
        <div class="text-sm text-gray-700 dark:text-gray-200">
          Information will go here.
        </div>
      </td>
    </tr>
    """
  end
end
