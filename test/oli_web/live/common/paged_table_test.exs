defmodule OliWeb.Common.PagedTableTest do
  use ExUnit.Case, async: true

  alias OliWeb.Common.{PagedTable, StripedPagedTable}
  alias OliWeb.Common.InstructorDashboardPagedTable

  @table_model %{sort_by_spec: %{name: :name}, sort_order: :asc}

  for table_module <- [PagedTable, StripedPagedTable, InstructorDashboardPagedTable] do
    test "#{inspect(table_module)} resets the offset when sorting" do
      socket = %{assigns: %{table_model: @table_model}}

      patch_fn = fn _socket, changes -> changes end

      assert %{sort_by: "name", sort_order: :desc, offset: 0} =
               unquote(table_module).delegate_handle_event(
                 "paged_table_sort",
                 %{"sort_by" => "name"},
                 socket,
                 patch_fn,
                 :table_model
               )
    end
  end
end
