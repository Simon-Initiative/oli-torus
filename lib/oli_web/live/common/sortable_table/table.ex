defmodule OliWeb.Common.SortableTable.Table do
  use Phoenix.Component

  alias OliWeb.Common.Table.ColumnSpec
  alias OliWeb.Icons

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
      <%= if @column_spec.tooltip && Map.get(@column_spec, :tooltip_icon, false) do %>
        <span class="inline-flex items-center gap-1.5">
          <button
            type="button"
            id={tooltip_id(@column_spec)}
            class="inline-flex h-8 w-8 items-center justify-center align-middle bg-transparent p-0 text-Icon-icon-accent-orange focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Text-text-link"
            phx-hook="GlobalTooltip"
            data-tooltip={@column_spec.tooltip}
            data-tooltip-style="body"
            data-tooltip-stop-propagation="true"
            aria-label={"#{@column_spec.label} help"}
          >
            <Icons.support class="h-5 w-5 stroke-current" />
          </button>
          <span>{@column_spec.label}</span>
        </span>
      <% else %>
        <%= if @column_spec.tooltip do %>
          <span id={@column_spec.name} title={@column_spec.tooltip} phx-hook="TooltipInit">
            {@column_spec.label}
          </span>
        <% else %>
          {@column_spec.label}
        <% end %>
      <% end %>

      <%= if @column_spec.sortable do %>
        <Icons.chevron_down
          width="20"
          height="20"
          class={"inline fill-black dark:fill-white " <> if @sort_direction_cls == "up", do: "", else: "rotate-180 "}
        />
      <% end %>
    </th>
    """
  end

  defp render_row(assigns, row) do
    row_class =
      if id_field(row, assigns.model) == assigns.model.selected do
        "border-b table-active"
      else
        if assigns.select != nil and assigns.select != "" do
          "border-b selectable"
        else
          "border-b"
        end
      end

    row_class = row_class <> " #{assigns[:additional_row_class]}"

    assigns = Map.merge(assigns, %{row: row, row_class: row_class})

    ~H"""
    <tr
      id={id_field(@row, @model)}
      class={@row_class <> if Map.get(@row, :selected) || id_field(@row, @model) == @model.selected, do: " bg-delivery-primary-100 shadow-inner dark:bg-gray-700 dark:text-black", else: ""}
      aria-selected={if Map.get(@row, :selected), do: "true", else: "false"}
      phx-click={if @select != nil and @select != "", do: @select, else: nil}
      phx-value-id={id_field(@row, @model)}
    >
      <%= for column_spec <- @model.column_specs do %>
        <td class={"#{column_spec.td_class} border-r p-2"}>
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
      <thead>
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
        <%= for row <- @model.rows do %>
          {render_row(
            with_data(
              %{
                model: @model,
                sort: @sort,
                select: @select,
                additional_table_class: @additional_table_class,
                additional_row_class: @additional_row_class
              },
              @model.data
            ),
            row
          )}
        <% end %>
      </tbody>
    </table>
    """
  end

  defp with_data(assigns, data) do
    Map.merge(assigns, data)
  end

  defp tooltip_id(%{tooltip_id: tooltip_id}) when is_binary(tooltip_id) and tooltip_id != "",
    do: tooltip_id

  defp tooltip_id(%{name: name}), do: "#{name}-column-tooltip"
end
