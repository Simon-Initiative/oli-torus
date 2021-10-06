defmodule OliWeb.Common.SortableTable.TableHandlers do
  def get_int_param(params, name, default_value) do
    case params[name] do
      nil ->
        default_value

      value ->
        case Integer.parse(value) do
          {num, _} -> num
          _ -> default_value
        end
    end
  end

  def get_str_param(params, name, default_value) do
    case params[name] do
      nil ->
        default_value

      value ->
        value
    end
  end

  def get_boolean_param(params, name, default_value) do
    case params[name] do
      nil ->
        default_value

      "false" ->
        false

      "true" ->
        true

      _ ->
        default_value
    end
  end

  def get_atom_param(params, name, valid, default_value) do
    case params[name] do
      nil ->
        default_value

      value ->
        case MapSet.new(valid) |> MapSet.member?(value) do
          true -> String.to_existing_atom(value)
          _ -> default_value
        end
    end
  end

  defmacro __using__(_options) do
    quote do
      import unquote(__MODULE__)

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      alias OliWeb.Common.Table.SortableTableModel
      alias OliWeb.Router.Helpers, as: Routes

      def handle_event("change_filter", %{"value" => filter}, socket) do
        {:noreply, assign(socket, filter: filter)}
      end

      def handle_event("apply_filter", _, socket) do
        {:noreply,
         push_patch(socket,
           to:
             @table_push_patch_path.(
               socket,
               get_patch_params(
                 socket.assigns.table_model,
                 socket.assigns.offset,
                 socket.assigns.filter
               )
             )
         )}
      end

      def handle_event("reset_filter", _, socket) do
        {:noreply,
         push_patch(socket,
           to:
             @table_push_patch_path.(
               socket,
               get_patch_params(
                 socket.assigns.table_model,
                 socket.assigns.offset,
                 ""
               )
             )
         )}
      end

      def handle_event("page_change", %{"offset" => offset}, socket) do
        {:noreply,
         push_patch(socket,
           to:
             @table_push_patch_path.(
               socket,
               get_patch_params(
                 socket.assigns.table_model,
                 String.to_integer(offset),
                 socket.assigns.applied_filter
               )
             )
         )}
      end

      def handle_event("sort", %{"sort_by" => sort_by}, socket) do
        table_model =
          SortableTableModel.update_sort_params(
            socket.assigns.table_model,
            String.to_existing_atom(sort_by)
          )

        offset = socket.assigns.offset

        {:noreply,
         push_patch(socket,
           to:
             @table_push_patch_path.(
               socket,
               get_patch_params(table_model, offset, socket.assigns.applied_filter)
             )
         )}
      end

      defp get_patch_params(table_model, offset, filter) do
        Map.merge(
          %{"offset" => offset, "filter" => filter},
          SortableTableModel.to_params(table_model)
        )
      end

      def handle_params(params, _, socket) do
        offset = get_int_param(params, "offset", 0)

        # Ensure that the offset is 0 or one minus a factor of the limit. So for a
        # limit of 20, valid offsets or 0, 20, 40, etc.  This logic overrides any attempt
        # to manually change URL offset param.
        offset =
          case rem(offset, socket.assigns.limit) do
            0 -> offset
            _ -> 0
          end

        filter = get_str_param(params, "filter", "")

        # First update the rows of the sortable table model to be all products, then apply the sort,
        # then slice the model rows according to the paging settings

        filtered = @table_filter_fn.(socket, filter)

        table_model =
          Map.put(socket.assigns.table_model, :rows, filtered)
          |> SortableTableModel.update_from_params(params)
          |> then(fn table_model ->
            Map.put(
              table_model,
              :rows,
              Enum.slice(table_model.rows, offset, socket.assigns.limit)
            )
          end)

        {:noreply,
         assign(socket,
           table_model: table_model,
           offset: offset,
           applied_filter: filter,
           filter: filter,
           total_count: length(filtered)
         )}
      end
    end
  end
end
