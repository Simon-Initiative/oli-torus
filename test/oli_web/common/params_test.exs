defmodule OliWeb.Common.ParamsTest do
  use ExUnit.Case, async: true

  alias OliWeb.Common.Params

  describe "get_atom_param/4" do
    test "returns the allowed value when it matches" do
      assert Params.get_atom_param(%{"sort_order" => "desc"}, "sort_order", [:asc, :desc], :asc) ==
               :desc
    end

    test "falls back to the default when the parameter is absent" do
      assert Params.get_atom_param(%{}, "sort_order", [:asc, :desc], :asc) == :asc
    end

    test "falls back to the default for a value outside the allow list" do
      assert Params.get_atom_param(%{"sort_order" => "title"}, "sort_order", [:asc, :desc], :asc) ==
               :asc
    end

    test "falls back to the default for a value that is not an existing atom" do
      assert Params.get_atom_param(
               %{"sort_order" => "sideways_#{System.unique_integer([:positive])}"},
               "sort_order",
               [:asc, :desc],
               :asc
             ) == :asc
    end

    test "falls back to the default when the value is not a string" do
      assert Params.get_atom_param(%{"sort_order" => ["asc"]}, "sort_order", [:asc, :desc], :asc) ==
               :asc
    end
  end
end
