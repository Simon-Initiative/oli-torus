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
      assert Floki.find(doc, "th[aria-sort]") == []
    end

    test "with sort_button the click moves to a <button> inside the <th> that carries its own sort_by" do
      doc = render_table(sort_button: true)

      assert Floki.find(doc, "th[phx-click]") == []

      assert [button] =
               Floki.find(doc, ~s(th button[phx-click="sort_event"][phx-value-sort_by="name"]))

      assert button |> Floki.text() |> String.trim() == "Name"
      assert Floki.attribute(button, "aria-label") == ["Sort by Name"]
      assert Floki.find(doc, "th button") |> length() == 2
      assert [_] = Floki.find(doc, ~s(th[phx-value-sort_by="name"]))
    end

    test "with sort_button every sortable column exposes aria-sort, with its direction" do
      doc = render_table(sort_button: true)

      assert [_] = Floki.find(doc, ~s(th[phx-value-sort_by="name"][aria-sort="ascending"]))
      assert [_] = Floki.find(doc, ~s(th[phx-value-sort_by="age"][aria-sort="none"]))
      assert Floki.find(doc, ~s(th[phx-value-sort_by="id"][aria-sort])) == []

      doc = render_table(sort_button: true, model: %{model() | sort_order: :desc})
      assert [_] = Floki.find(doc, ~s(th[phx-value-sort_by="name"][aria-sort="descending"]))
    end

    test "sort arrows are hidden from assistive technology" do
      doc = render_table()

      assert Floki.find(doc, "th svg") |> length() == 2
      assert Floki.find(doc, ~s{th svg:not([aria-hidden="true"])}) == []
    end

    test "header_info renders inside the <th> but outside the sort button" do
      info = Phoenix.HTML.raw(~s(<button id="name-info">i</button>))
      [name_spec | specs] = model().column_specs

      doc =
        render_table(
          sort_button: true,
          model: %{model() | column_specs: [%{name_spec | header_info: info} | specs]}
        )

      assert [_] = Floki.find(doc, ~s(th[phx-value-sort_by="name"] #name-info))
      assert Floki.find(doc, "th button #name-info") == []
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
