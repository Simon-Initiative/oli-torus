defmodule Oli.Math.ExactFormTest do
  use ExUnit.Case, async: true

  alias Oli.Math.Algebraic
  alias Oli.Math.ExactForm

  # @ac "AC-013" Public bridge calls the stable `torus_math` exact-form APIs.
  # @ac "AC-014" Bridge exposes stable exact-form debug formatting.
  # @ac "AC-019" Debug strings are deterministic through the public bridge.
  describe "default_config/0 and check/2" do
    test "call the public Gleam exact-form boundary" do
      assert ExactForm.default_config() == :no_form_constraint

      assert {:form_satisfied, {:observed_form_summary, :observed_integer, {:span, 0, 1}}} =
               ExactForm.check("7", :require_integer)
    end
  end

  describe "check_algebraic/4" do
    test "calls the public Gleam form-aware algebraic boundary" do
      result =
        ExactForm.check_algebraic(
          "4/5",
          "8/10",
          Algebraic.default_config(),
          :require_simplified_fraction
        )

      assert {:semantics_passed_form_failed,
              {:algebraic_equivalence_result, {:equivalent, _}, _expected_debug, _candidate_debug,
               _samples, _rejected_samples, _summary, _config_summary},
              {:form_not_satisfied, {:observed_form_summary, :observed_fraction, {:span, 0, 4}},
               [{:unsimplified_fraction, 8, 10, 2}]}} = result
    end
  end

  describe "result_debug/1 and form_aware_result_debug/1" do
    test "delegate stable debug formatting to Gleam" do
      form_result = ExactForm.check("8/10", :require_simplified_fraction)

      assert ExactForm.result_debug(form_result) ==
               "FormNotSatisfied(observed=ObservedFormSummary(kind=ObservedFraction,span=Span(0,4)),failures=[UnsimplifiedFraction(numerator=8,denominator=10,gcd=2)])"

      form_aware_result =
        ExactForm.check_algebraic(
          "4/5",
          "8/10",
          Algebraic.default_config(),
          :require_simplified_fraction
        )

      assert ExactForm.form_aware_result_debug(form_aware_result) =~
               "SemanticsPassedFormFailed(equivalence=AlgebraicEquivalenceResult"

      assert ExactForm.form_aware_result_debug(form_aware_result) =~
               "form=FormNotSatisfied(observed=ObservedFormSummary(kind=ObservedFraction"
    end
  end

  describe "config_from_form/1" do
    test "converts each exact-form selector into a generated Gleam config term" do
      assert ExactForm.config_from_form(%{"form_constraint" => "none"}) ==
               {:ok, :no_form_constraint}

      assert ExactForm.config_from_form(%{"form_constraint" => "integer"}) ==
               {:ok, :require_integer}

      assert ExactForm.config_from_form(%{"form_constraint" => "fraction"}) ==
               {:ok, :require_fraction}

      assert ExactForm.config_from_form(%{"form_constraint" => "simplified_fraction"}) ==
               {:ok, :require_simplified_fraction}

      assert ExactForm.config_from_form(%{
               "form_constraint" => "decimal",
               "decimal_precision_rule" => "any"
             }) == {:ok, {:require_decimal, :any_decimal_places}}
    end

    test "converts decimal precision selector values" do
      assert ExactForm.config_from_form(%{
               "form_constraint" => "decimal",
               "decimal_precision_rule" => "exactly",
               "decimal_precision_count" => "2"
             }) == {:ok, {:require_decimal, {:decimal_places, :exactly, 2}}}

      assert ExactForm.config_from_form(%{
               "form_constraint" => "decimal",
               "decimal_precision_rule" => "at_least",
               "decimal_precision_count" => 3
             }) == {:ok, {:require_decimal, {:decimal_places, :at_least, 3}}}

      assert ExactForm.config_from_form(%{
               "form_constraint" => "decimal",
               "decimal_precision_rule" => "at_most",
               "decimal_precision_count" => "4"
             }) == {:ok, {:require_decimal, {:decimal_places, :at_most, 4}}}
    end

    test "returns structured errors for unsupported selectors and bad precision counts" do
      assert {:error, [%{field: "form_constraint", message: form_message}]} =
               ExactForm.config_from_form(%{"form_constraint" => "bogus"})

      assert form_message =~ "must be none"

      assert ExactForm.config_from_form(%{
               "form_constraint" => "decimal",
               "decimal_precision_rule" => "bogus"
             }) ==
               {:error,
                [
                  %{
                    field: "decimal_precision_rule",
                    message: "must be any, exactly, at_least, or at_most"
                  }
                ]}

      assert ExactForm.config_from_form(%{
               "form_constraint" => "decimal",
               "decimal_precision_rule" => "exactly",
               "decimal_precision_count" => "-1"
             }) ==
               {:error,
                [%{field: "decimal_precision_count", message: "must be a non-negative integer"}]}

      assert ExactForm.config_from_form(%{
               "form_constraint" => "decimal",
               "decimal_precision_rule" => "at_least",
               "decimal_precision_count" => "two"
             }) ==
               {:error,
                [%{field: "decimal_precision_count", message: "must be a non-negative integer"}]}
    end

    test "does not create dynamic atoms from selector input" do
      ExactForm.config_from_form(%{"form_constraint" => "warmup"})
      before_count = :erlang.system_info(:atom_count)

      for index <- 1..100 do
        assert {:error, [%{field: "form_constraint"}]} =
                 ExactForm.config_from_form(%{"form_constraint" => "unknown_#{index}"})
      end

      assert :erlang.system_info(:atom_count) == before_count
    end
  end
end
