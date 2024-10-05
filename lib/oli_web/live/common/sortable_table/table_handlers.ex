defmodule OliWeb.Common.SortableTable.TableHandlers do
  alias OliWeb.Common.Params

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

      def handle_event("change_search", %{"value" => query}, socket) do
        {:noreply, assign(socket, query: query)}
      end

      def handle_event("apply_search", _, socket) do
        {:noreply,
         push_patch(socket,
           to:
             @table_push_patch_path.(
               socket,
               get_patch_params(
                 socket.assigns.table_model,
                 0,
                 socket.assigns.query,
                 Map.get(socket.assigns, :filter, %{}),
                 nil,
                 socket.assigns.sidebar_expanded
               )
             ),
           replace: true
         )}
      end

      def handle_event("reset_search", _, socket) do
        {:noreply,
         push_patch(socket,
           to:
             @table_push_patch_path.(
               socket,
               get_patch_params(
                 socket.assigns.table_model,
                 0,
                 "",
                 Map.get(socket.assigns, :filter, %{}),
                 nil,
                 socket.assigns.sidebar_expanded
               )
             ),
           replace: true
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
                 socket.assigns.applied_query,
                 Map.get(socket.assigns, :filter, %{}),
                 nil,
                 socket.assigns.sidebar_expanded
               )
             ),
           replace: true
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
               get_patch_params(
                 table_model,
                 offset,
                 socket.assigns.applied_query,
                 Map.get(socket.assigns, :filter, %{}),
                 nil,
                 socket.assigns.sidebar_expanded
               )
             ),
           replace: true
         )}
      end

      def handle_event("sort", _, socket), do: {:noreply, socket}

      def handle_event(
            "apply_filter",
            params,
            socket
          ) do
        filter = Map.get(params, "filter", socket.assigns.filter)

        {:noreply,
         push_patch(socket,
           to:
             @table_push_patch_path.(
               socket,
               get_patch_params(
                 socket.assigns.table_model,
                 0,
                 socket.assigns.query,
                 filter,
                 nil,
                 socket.assigns.sidebar_expanded
               )
             ),
           replace: true
         )}
      end

      defp get_patch_params(
             table_model,
             offset,
             query,
             filter,
             selected \\ nil,
             sidebar_expanded \\ true
           ) do
        Map.merge(
          %{
            "offset" => offset,
            "query" => query,
            "filter" => filter,
            "selected" => selected,
            "sidebar_expanded" => sidebar_expanded
          },
          SortableTableModel.to_params(table_model)
        )
      end

      defp sidebar_expanded(nil), do: true
      defp sidebar_expanded("false"), do: false
      defp sidebar_expanded("true"), do: true

      def handle_params(params, _, socket) do
        offset = Params.get_int_param(params, "offset", 0)

        sidebar_expanded = sidebar_expanded(params["sidebar_expanded"])

        # Ensure that the offset is 0 or one minus a factor of the limit. So for a
        # limit of 20, valid offsets or 0, 20, 40, etc.  This logic overrides any attempt
        # to manually change URL offset param.
        offset =
          case rem(offset, socket.assigns.limit) do
            0 -> offset
            _ -> 0
          end

        query = Params.get_param(params, "query", "")

        selected = Params.get_param(params, "selected", "")

        filter =
          Params.get_param(
            params,
            "filter",
            Map.get(socket.assigns, :filter, %{})
          )

        # First update the rows of the sortable table model to be all products, then apply the sort,
        # then slice the model rows according to the paging settings

        filtered = @table_filter_fn.(socket, query, filter)

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
           applied_query: query,
           query: query,
           filter: filter,
           total_count: length(filtered),
           selected: selected,
           sidebar_expanded: sidebar_expanded,
           params:
             get_patch_params(table_model, offset, query, filter, selected, sidebar_expanded)
         )}
      end

      def withelist_filter(filter, filter_name, allowed_values) do
        Map.get(filter, filter_name)
        |> String.split(",")
        |> Enum.filter(&(&1 in allowed_values))
      end
    end
  end
end
