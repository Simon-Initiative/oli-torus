defmodule OliWeb.Common.Table.SortableTable do
  use Phoenix.LiveComponent

  alias OliWeb.Common.Table.ColumnSpec

  def th(assigns, column_spec, sort_by_spec, sort_order, event_suffix) do
    assigns =
      assigns
      |> assign(:column_spec, column_spec)
      |> assign(:sort_by_spec, sort_by_spec)
      |> assign(:sort_order, sort_order)
      |> assign(:event_suffix, event_suffix)

    ~H"""
    <th
      style="cursor: pointer;"
      phx-click={"sort#{@event_suffix}"}
      phx-value-sort_by={@column_spec.name}
    >
      <%= if @column_spec.tooltip do %>
        <span data-bs-toggle="tooltip" title={@column_spec.tooltip}>
          {@column_spec.label}
        </span>
      <% else %>
        {@column_spec.label}
      <% end %>
      <%= if @sort_by_spec == @column_spec do %>
        <i class={"fas fa-sort-#{if @sort_order == :asc do "up" else "down" end}"}></i>
      <% end %>
    </th>
    """
  end

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

  def render(assigns) do
    ~H"""
    <table class="table table-striped table-bordered">
      <thead>
        <tr>
          <%= for column_spec <- @model.column_specs do %>
            {th(
              with_data(assigns, @model.data),
              column_spec,
              @model.sort_by_spec,
              @model.sort_order,
              @model.event_suffix
            )}
          <% end %>
        </tr>
      </thead>
      <tbody>
        <%= for row <- @model.rows do %>
          <.row model={@model} row={row} />
        <% end %>
      </tbody>
    </table>
    """
  end

  defp row(assigns) do
    assigns =
      assigns
      |> assign(:id, id_field(assigns.row, assigns.model))
      |> assign(
        :class,
        if assigns.row == assigns.model.selected do
          "table-active"
        else
          ""
        end
      )

    ~H"""
    <tr id={@id} class={@class}>
      <%= for column_spec <- @model.column_specs do %>
        <td>
          {case column_spec.render_fn do
            nil -> ColumnSpec.default_render_fn(column_spec, @row)
            func -> func.(with_data(assigns, @model.data), @row, column_spec)
          end}
        </td>
      <% end %>
    </tr>
    """
  end

  defp with_data(assigns, data) do
    Map.merge(assigns, data)
  end
end
