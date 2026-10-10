defmodule OliWeb.Common.SortableTable.StripedTableTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Common.SortableTable.StripedTable
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  defp model do
    {:ok, model} =
      SortableTableModel.new(
        rows: [%{id: 1, name: "Bravo"}, %{id: 2, name: "Alpha"}],
        column_specs: [
          %ColumnSpec{name: :name, label: "Name"},
          %ColumnSpec{name: :age, label: "Age"},
          %ColumnSpec{name: :id, label: "Identifier", sortable: false}
        ],
        event_suffix: "",
        id_field: [:id]
      )

    model
  end

  defp render_table(extra \\ []) do
    [model: model(), sort: "sort_event"]
    |> Keyword.merge(extra)
    |> then(fn assigns -> render_component(&StripedTable.render/1, assigns) end)
    |> Floki.parse_document!()
  end

  describe "sort headers" do
    test "by default the <th> itself carries the sort click and no button" do
      doc = render_table()

      assert [th] = Floki.find(doc, ~s(th[phx-click="sort_event"][phx-value-sort_by="name"]))
      assert Floki.find(th, "button") == []
      assert Floki.find(doc, ~s(th[phx-click])) |> length() == 2
    end

    test "with sort_button the click moves to a <button> inside the <th> that carries its own sort_by" do
      doc = render_table(sort_button: true)

      assert Floki.find(doc, "th[phx-click]") == []

      assert [button] =
               Floki.find(doc, ~s(th button[phx-click="sort_event"][phx-value-sort_by="name"]))

      assert button |> Floki.text() |> String.trim() == "Name"
      assert Floki.find(doc, "th button") |> length() == 2
      assert [_] = Floki.find(doc, ~s(th[phx-value-sort_by="name"]))
    end

    test "with sort_button only the sorted column exposes aria-sort, with its direction" do
      doc = render_table(sort_button: true)

      assert [_] = Floki.find(doc, ~s(th[phx-value-sort_by="name"][aria-sort="ascending"]))
      assert Floki.find(doc, ~s(th[phx-value-sort_by="age"][aria-sort])) == []
      assert Floki.find(doc, ~s(th[phx-value-sort_by="id"][aria-sort])) == []
      assert Floki.find(doc, "th[aria-sort]") |> length() == 1

      doc = render_table(sort_button: true, model: %{model() | sort_order: :desc})
      assert [_] = Floki.find(doc, ~s(th[phx-value-sort_by="name"][aria-sort="descending"]))
    end

    test "without sort_button no header exposes aria-sort" do
      assert render_table() |> Floki.find("th[aria-sort]") == []
    end
  end

  describe "table id" do
    test "uses the given id as is, and a generated one otherwise" do
      assert [_] = render_table(id: "scoring-table") |> Floki.find(~s(table#scoring-table))

      assert [{"table", attrs, _}] = render_table() |> Floki.find("table")
      assert {"id", "sortable-table-" <> _} = List.keyfind(attrs, "id", 0)
    end
  end
end
