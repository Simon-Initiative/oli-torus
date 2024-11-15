defmodule OliWeb.Common.InstructorDashboardLearningObjectivesTable do
  use Phoenix.Component
  alias OliWeb.Common.ExpandableTable
  alias OliWeb.Common.Paging

  attr :total_count, :integer, required: true
  attr :filter, :string, default: ""
  attr :limit, :integer, required: true
  attr :offset, :integer, required: true
  attr :table_model, :map, required: true
  attr :allow_selection, :boolean, required: false, default: false
  attr :sort, :string, default: "paged_table_sort"
  attr :page_change, :string, default: "paged_table_page_change"
  attr :selection_change, :string, default: "paged_table_selection_change"
  attr :limit_change, :string, default: "paged_table_limit_change"
  attr :show_bottom_paging, :boolean, default: true

  attr :additional_table_class, :string, default: ""
  attr :render_top_info, :boolean, default: true
  attr :scrollable, :boolean, default: true
  attr :show_limit_change, :boolean, default: false
  attr :no_records_message, :string, default: "None exist"

  def render(assigns) do
    ~H"""
    <div class={if @scrollable, do: "overflow-x-scroll inline"}>
      <%= if @filter != "" and @render_top_info do %>
        <strong>Results filtered on &quot;<%= @filter %>&quot;</strong>
      <% end %>

      <%= if @total_count > 0 do %>
        <div :if={@total_count <= @limit and @render_top_info} class="px-5 py-2">
          Showing all results (<%= @total_count %> total)
        </div>
        <%= render_table(%{
          allow_selection: @allow_selection,
          table_model: @table_model,
          sort: @sort,
          selection_change: @selection_change,
          additional_table_class: @additional_table_class
        }) %>
        <Paging.render
          id="footer_paging"
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
          click={@page_change}
          limit_change={@limit_change}
          has_shorter_label={true}
          show_limit_change={true}
          should_add_empty_flex={false}
          is_page_size_right={true}
        />
      <% else %>
        <div class="bg-white dark:bg-gray-800 dark:text-white px-10 my-5">
          <p><%= @no_records_message %></p>
        </div>
      <% end %>
    </div>
    """
  end

  def render_table(assigns) do
    if assigns.allow_selection do
      ~H"""
      <ExpandableTable.render
        model={@table_model}
        sort={@sort}
        select={@selection_change}
        additional_table_class={@additional_table_class}
      />
      """
    else
      ~H"""
      <ExpandableTable.render
        model={@table_model}
        sort={@sort}
        additional_table_class={@additional_table_class}
      />
      """
    end
  end

  @spec handle_delegated(<<_::64, _::_*8>>, map, any, (any, any -> any), any) :: any
  def handle_delegated(event, params, socket, patch_fn, model_key \\ :table_model) do
    delegate_handle_event(event, params, socket, patch_fn, model_key)
  end

  def delegate_handle_event("paged_table_page_change", %{"offset" => offset}, socket, patch_fn, _) do
    patch_fn.(socket, %{offset: offset})
  end

  def delegate_handle_event(
        "paged_table_limit_change",
        params,
        %{assigns: %{params: current_params}} = socket,
        patch_fn,
        _
      ) do
    new_limit = OliWeb.Common.Params.get_int_param(params, "limit", 20)

    new_offset =
      if socket.assigns.total_count < new_limit do
        0
      else
        OliWeb.Common.PagingParams.calculate_new_offset(
          current_params.offset,
          new_limit,
          socket.assigns.total_count
        )
      end

    patch_fn.(socket, %{limit: new_limit, offset: new_offset})
  end

  def delegate_handle_event(
        "paged_table_selection_change",
        %{"id" => selected},
        socket,
        patch_fn,
        _
      ) do
    patch_fn.(socket, %{selected: selected})
  end

  # handle change of selection
  def delegate_handle_event(
        "paged_table_sort",
        %{"sort_by" => sort_by},
        socket,
        patch_fn,
        model_key
      ) do
    sort_order =
      case Atom.to_string(socket.assigns[model_key].sort_by_spec.name) do
        ^sort_by ->
          if socket.assigns[model_key].sort_order == :asc do
            :desc
          else
            :asc
          end

        _ ->
          socket.assigns[model_key].sort_order
      end

    patch_fn.(socket, %{
      sort_by: sort_by,
      sort_order: sort_order
    })
  end

  def delegate_handle_event(_, _, _, _) do
    :not_handled
  end
end

defmodule OliWeb.Common.ExpandableTable do
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
        <OliWeb.Icons.chevron_down
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
      aria-selected={if Map.get(@row, :selected), do: "true", else: "false"}
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
