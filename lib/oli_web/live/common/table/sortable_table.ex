defmodule OliWeb.Common.Table.SortableTable do
  use Phoenix.LiveComponent

  alias OliWeb.Common.Table.ColumnSpec
  alias OliWeb.Icons

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
          <span data-bs-toggle="tooltip" title={@column_spec.tooltip}>
            {@column_spec.label}
          </span>
        <% else %>
          {@column_spec.label}
        <% end %>
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

  defp tooltip_id(%{tooltip_id: tooltip_id}) when is_binary(tooltip_id) and tooltip_id != "",
    do: tooltip_id

  defp tooltip_id(%{name: name}), do: "#{name}-column-tooltip"
end
