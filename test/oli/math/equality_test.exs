defmodule Oli.Math.EqualityTest do
  use ExUnit.Case, async: true

  @numeric_equal_json """
  {
    "version": 1,
    "mode": "numeric",
    "comparison": { "type": "equal", "expected": "2" },
    "tolerance": { "type": "none" },
    "representation": { "type": "any" },
    "precision": { "type": "none" }
  }
  """

  describe "decode_config/1" do
    test "decodes equalityConfig JSON through the public Gleam boundary" do
      assert {:ok,
              {:equality_spec, 1,
               {:numeric,
                {:numeric_spec, {:equal, {:numeric_input, "2"}}, :no_tolerance,
                 :any_representation, :no_precision}}}} =
               Oli.Math.Equality.decode_config(@numeric_equal_json)
    end
  end

  describe "evaluate_json/2" do
    test "evaluates matching numeric JSON config without duplicating numeric semantics" do
      assert {:ok, {:equality_matched, [:numeric_comparison_matched]}} =
               Oli.Math.Equality.evaluate_json(@numeric_equal_json, "2")
    end

    test "returns invalid submitted answer diagnostics from Gleam" do
      assert {:ok, {:invalid_submitted_answer, [:numeric_parse_failure]}} =
               Oli.Math.Equality.evaluate_json(@numeric_equal_json, "two")
    end

    test "returns decode errors before evaluation" do
      assert {:error, {:missing_field, "version"}} =
               Oli.Math.Equality.evaluate_json(~s({"mode":"numeric"}), "2")
    end
  end
end
