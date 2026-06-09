defmodule Oli.Math.AlgebraicTest do
  use ExUnit.Case, async: true

  alias Oli.Math.Algebraic

  describe "default_config/0 and check/3" do
    test "call the public Gleam algebraic equivalence boundary" do
      config = Algebraic.default_config()

      assert {:algebraic_equivalence_config, :infer_from_expected, :default_supported_functions,
              {:domain_config, []}, {:sampling_config, 42, 8, 64, true}, _, _, _,
              :detailed_diagnostics} = config

      assert {:algebraic_equivalence_result, {:equivalent, 8}, _expected_debug, _candidate_debug,
              samples, _rejected_samples, summary, _config_summary} =
               Algebraic.check("2(x+3)", "2x+6", config)

      assert length(samples) == 8
      assert {:equivalence_summary, :equivalent_outcome, 8, 8, 8, 0, :none, ["x"]} = summary
    end
  end

  describe "config_from_form/1" do
    test "converts prototype form values into Gleam config terms with per-variable domains" do
      assert {:ok,
              {:algebraic_equivalence_config, {:explicit_allowed_variables, ["x", "y"]},
               :default_supported_functions,
               {:domain_config,
                [
                  {:variable_domain, "x", {:inclusive, -2.0}, {:exclusive, 5.0}, x_exclusions,
                   true, x_preferred_values},
                  {:variable_domain, "y", {:exclusive, 1.0}, {:inclusive, 9.0}, [], false, []}
                ]}, {:sampling_config, 7, 5, 20, false}, _eval,
               {:absolute_or_relative_tolerance, 0.01, 0.02, 1.0e-9}, :expected_defined_domain,
               :detailed_diagnostics}} =
               Algebraic.config_from_form(%{
                 "allowed_variables" => "x, y",
                 "seed" => "7",
                 "desired_count" => "5",
                 "max_attempts" => "20",
                 "include_special_points" => "false",
                 "tolerance_type" => "absolute_or_relative",
                 "abs_tolerance" => "0.01",
                 "rel_tolerance" => "0.02",
                 "epsilon" => "0.000000001",
                 "domains" => [
                   %{
                     "name" => "x",
                     "lower" => "-2",
                     "lower_inclusive" => "true",
                     "upper" => "5",
                     "upper_inclusive" => "false",
                     "integer_only" => "on",
                     "exclusions" => "0, 1",
                     "preferred_values" => "-1 2"
                   },
                   %{
                     "name" => "y",
                     "lower" => "1",
                     "lower_bound" => "exclusive",
                     "upper" => "9",
                     "upper_bound" => "inclusive"
                   }
                 ]
               })

      assert x_exclusions == [0.0, 1.0]
      assert x_preferred_values == [-1.0, 2.0]
    end

    test "supports sample_count alias and default tolerance for prototype forms" do
      assert {:ok,
              {:algebraic_equivalence_config, :infer_from_expected, :default_supported_functions,
               {:domain_config, []}, {:sampling_config, 11, 3, 9, true}, _eval,
               {:absolute_or_relative_tolerance, 0.0001, 0.0001, 1.0e-12},
               :expected_defined_domain, :detailed_diagnostics}} =
               Algebraic.config_from_form(%{
                 "seed" => "11",
                 "sample_count" => "3",
                 "max_attempts" => "9",
                 "include_special_points" => "true"
               })
    end

    test "returns structured errors without crashing on invalid form data" do
      assert {:error, errors} =
               Algebraic.config_from_form(%{
                 "seed" => "abc",
                 "desired_count" => "NaN",
                 "tolerance_type" => "bogus",
                 "domains" => [
                   %{"name" => "x", "lower" => "low", "upper" => "10"},
                   %{"lower" => "0", "upper" => "1"}
                 ]
               })

      assert %{field: "seed", message: "must be an integer"} in errors
      assert %{field: "desired_count", message: "must be an integer"} in errors
      assert %{field: "tolerance_type", message: ~s(unsupported tolerance type "bogus")} in errors
      assert %{field: "domains[0].lower", message: "must be a number"} in errors
      assert %{field: "domains[1].name", message: "is required"} in errors
    end
  end

  describe "result_debug/1" do
    test "delegates stable debug formatting to Gleam" do
      result = Algebraic.check("1", "2", Algebraic.default_config())

      assert Algebraic.result_debug(result) =~
               "NotEquivalent(reason=ValueMismatch(first_failure=SampleComparison"

      assert Algebraic.result_debug(result) =~
               "summary=EquivalenceSummary(outcome_category=NotEquivalent"
    end
  end
end
