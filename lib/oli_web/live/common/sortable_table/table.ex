defmodule OliWeb.Common.SortableTable.Table do
  use Phoenix.Component

  alias OliWeb.Common.Table.ColumnSpec

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

    assigns =
      Map.merge(assigns, %{sort_direction_cls: sort_direction_cls, column_spec: column_spec})

    ~H"""
    <th
      class={"#{@column_spec.th_class} border-b border-r p-2 bg-gray-100 #{if @column_spec.sortable, do: "cursor-pointer"}"}
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
      <%= if @column_spec.tooltip do %>
        <span id={@column_spec.name} title={@column_spec.tooltip} phx-hook="TooltipInit">
          <%= @column_spec.label %>
        </span>
      <% else %>
        <%= @column_spec.label %>
      <% end %>

      <%= if @column_spec.sortable do %>
        <i class={"fas fa-sort-" <> @sort_direction_cls} />
      <% end %>
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

    assigns = Map.merge(assigns, %{row: row, row_class: row_class})

    ~H"""
    <tr
      id={id_field(@row, @model)}
      class={@row_class <> if Map.get(@row, :selected) || id_field(@row, @model) == @model.selected, do: " bg-delivery-primary-100 shadow-inner dark:bg-gray-700 dark:text-black", else: ""}
      phx-click={@select}
      phx-value-id={id_field(@row, @model)}
    >
      <%= for column_spec <- @model.column_specs do %>
        <td class={"#{column_spec.td_class} border-r p-2"}>
          <div class={if Map.get(@model.data, :fade_data, false), do: "fade-text", else: ""}>
            <%= if is_nil(column_spec.render_fn) do %>
              <%= ColumnSpec.default_render_fn(column_spec, @row) %>
            <% else %>
              <%= column_spec.render_fn.(
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
              ) %>
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

  def render(assigns) do
    ~H"""
    <table class={"min-w-full border " <> @additional_table_class}>
      <thead>
        <tr>
          <%= for column_spec <- @model.column_specs do %>
            <%= render_th(
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
            ) %>
          <% end %>
        </tr>
      </thead>
      <tbody>
        <%= for row <- @model.rows do %>
          <%= render_row(
            with_data(
              %{
                model: @model,
                sort: @sort,
                select: @select,
                additional_table_class: @additional_table_class
              },
              @model.data
            ),
            row
          ) %>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp with_data(assigns, data) do
    Map.merge(assigns, data)
  end
end
