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

    test "keeps its side margins by default; a page can drop them to line its counts up with its own content" do
      assert classes(top_info(render_table(total_count: 3))) == ["px-5", "py-2"]

      default_paged = render_table([])
      assert "mx-4" in (default_paged |> Floki.find("#footer_paging") |> hd() |> classes())
      assert classes(paging_label(default_paged)) == ["ml-4"]

      assert classes(top_info(render_table(total_count: 3, top_info_class: "py-2"))) == ["py-2"]

      aligned_paged = render_table(paging_container_class: "")
      refute "mx-4" in (aligned_paged |> Floki.find("#footer_paging") |> hd() |> classes())
      assert classes(paging_label(aligned_paged)) == []
    end

    defp top_info(doc), do: own_text_node(doc, "div", ~r/^Showing all results/)
    defp paging_label(doc), do: own_text_node(doc, "#footer_paging > div", ~r/^Showing result/)

    defp own_text_node(doc, selector, text) do
      node =
        doc
        |> Floki.find(selector)
        |> Enum.find(&(Floki.text(&1, deep: false) |> String.trim() |> String.match?(text)))

      assert node, "no #{selector} reads #{inspect(text)}"
      node
    end

    defp classes(node), do: node |> Floki.attribute("class") |> Enum.flat_map(&String.split/1)
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
