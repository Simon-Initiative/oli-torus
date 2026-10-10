defmodule OliWeb.Common.StripedPagedTableTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Common.StripedPagedTable
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias Phoenix.LiveView.Socket

  describe "render/1" do
    defp render_table(extra) do
      {:ok, model} =
        SortableTableModel.new(
          rows: Enum.map(1..3, &%{id: &1, name: "Row #{&1}"}),
          column_specs: [%ColumnSpec{name: :name, label: "Name"}],
          event_suffix: "",
          id_field: [:id]
        )

      [table_model: model, total_count: 30, limit: 3, offset: 0]
      |> Keyword.merge(extra)
      |> then(fn assigns -> render_component(&StripedPagedTable.render/1, assigns) end)
      |> Floki.parse_document!()
    end

    test "shows the page-size control by default and hides it when show_limit_change is false" do
      assert [_] = render_table([]) |> Floki.find(~s(select[name="limit"]))
      assert render_table(show_limit_change: false) |> Floki.find(~s(select[name="limit"])) == []
    end

    test "passes a fixed table id and the sort_button opt-in through to the table" do
      doc = render_table(table_id: "scoring-table", sort_button: true)

      assert [_] = Floki.find(doc, "table#scoring-table")

      assert [_] =
               Floki.find(
                 doc,
                 ~s(th button[phx-click="paged_table_sort"][phx-value-sort_by="name"])
               )

      assert Floki.find(doc, "th[phx-click]") == []
    end
  end

  describe "handle_delegated/4" do
    test "sorting by the current column reverses the direction; a new column keeps it" do
      {:ok, model} =
        SortableTableModel.new(
          rows: [],
          column_specs: [
            %ColumnSpec{name: :name, label: "Name"},
            %ColumnSpec{name: :age, label: "Age"}
          ],
          event_suffix: "",
          id_field: [:id]
        )

      patch_fn = fn _socket, changes -> {:patched, changes} end

      sort = fn starting_order, sort_by ->
        socket = %Socket{assigns: %{table_model: %{model | sort_order: starting_order}}}

        StripedPagedTable.handle_delegated(
          "paged_table_sort",
          %{"sort_by" => sort_by},
          socket,
          patch_fn
        )
      end

      assert {:patched, %{sort_by: "name", sort_order: :asc}} = sort.(:desc, "name")
      assert {:patched, %{sort_by: "name", sort_order: :desc}} = sort.(:asc, "name")
      assert {:patched, %{sort_by: "age", sort_order: :desc}} = sort.(:desc, "age")
      assert {:patched, %{sort_by: "age", sort_order: :asc}} = sort.(:asc, "age")
    end

    test "returns :not_handled for an event the table does not own" do
      patch_fn = fn _socket, _params -> flunk("patch_fn must not be called") end

      assert :not_handled ==
               StripedPagedTable.handle_delegated(
                 "unknown_event",
                 %{"a" => 1},
                 %Socket{},
                 patch_fn
               )
    end
  end
end
