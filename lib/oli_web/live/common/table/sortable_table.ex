defmodule OliWeb.Common.Table.SortableTable do
  use Phoenix.LiveComponent

  alias OliWeb.Common.Table.ColumnSpec

  def th(assigns, column_spec, sort_by_spec, sort_order, event_suffix) do
    ~L"""
    <th style="cursor: pointer;" phx-click="sort<%= event_suffix %>" phx-value-sort_by="<%= column_spec.name %>">
      <%= column_spec.label %>
      <%= if sort_by_spec == column_spec do %>
        <i class="fas fa-sort-<%= if sort_order == :asc do "up" else "down" end %>"></i>
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
    ~L"""
    <table class="table table-striped table-bordered">
      <thead>
        <tr>
          <%= for column_spec <- @model.column_specs do %>
            <%= th(assigns, column_spec, @model.sort_by_spec, @model.sort_order, @model.event_suffix) %>
          <% end %>
        </tr>
      </thead>
      <tbody>
        <%= for row <- @model.rows do %>
          <%= if row == @model.selected do %>
          <tr id="<%= id_field(row, @model) %>" class="table-active">
          <% else %>
          <tr id="<%= id_field(row, @model) %>">
          <% end %>
            <%= for column_spec <- @model.column_specs do %>
              <td>
                <%= case column_spec.render_fn do
                  nil -> ColumnSpec.default_render_fn(column_spec, row)
                  func -> func.(assigns, row, column_spec)
                  end %>
              </td>
            <% end %>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end
end
