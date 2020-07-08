defmodule OliWeb.Common.Table.SortableTableModelTest do

  use ExUnit.Case, async: true

  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Common.Table.ColumnSpec


  describe "sorting" do
    setup do
      %{
        rows: [
          %{a: 1, b: 1, c: 5, d: 5},
          %{a: 2, b: 2, c: 4, d: 5},
          %{a: 3, b: 3, c: 3, d: 5},
          %{a: 4, b: 4, c: 2, d: 5},
          %{a: 5, b: 5, c: 1, d: 5},
        ]
      }
    end

    test "sorting", %{rows: rows} do

      column_specs = [
        %ColumnSpec{name: :a, label: "A"},
        %ColumnSpec{name: :c, label: "C"}
      ]

      {:ok, model} = SortableTableModel.new(rows: rows, column_specs: column_specs, event_suffix: "", id_field: :a)

      assert model.sort_by_spec == hd(column_specs)

      # change the sort column to c
      model = SortableTableModel.update_sort_params_and_sort(model, :c)
      assert model.sort_by_spec.name == :c
      assert hd(model.rows).c == 1

      # change to c again, triggering a change in sort direction
      model = SortableTableModel.update_sort_params_and_sort(model, :c)
      assert model.sort_by_spec.name == :c
      assert hd(model.rows).c == 5

      # change to a again
      model = SortableTableModel.update_sort_params_and_sort(model, :a)
      assert model.sort_by_spec.name == :a
      assert hd(model.rows).a == 5

    end

  end

end
