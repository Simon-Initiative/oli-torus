defmodule Oli.TorusDoc.Activities.MathExpressionConverterTest do
  use ExUnit.Case, async: true

  alias Oli.TorusDoc.ActivityConverter

  describe "short answer math_expression YAML" do
    test "supports every math expression subtype" do
      expected_shapes = %{
        "numeric" => {"numeric", nil},
        "algebraic" => {"algebraic_equivalence", nil},
        "number_with_units" => {"unit_aware", nil},
        "expression_with_units" => {"unit_aware", nil},
        "integer" => {"algebraic_equivalence", %{"type" => "integer"}},
        "decimal" => {"algebraic_equivalence", %{"type" => "decimal"}},
        "fraction" => {"algebraic_equivalence", %{"type" => "fraction"}},
        "simplified_fraction" => {"algebraic_equivalence", %{"type" => "simplified_fraction"}},
        "latex_direct" => {"latex_direct", nil}
      }

      for {subtype, {mode, form}} <- expected_shapes do
        yaml = """
        type: oli_short_answer
        stem_md: "Question?"
        input_type: math_expression
        math_expression:
          subtype: #{subtype}
          unit_policy:
            type: convertible_units
            units: ["m/s"]
        responses:
          - answer: "1"
            score: 1
            correct: true
        """

        assert {:ok, json} = ActivityConverter.from_yaml(yaml)

        response = json["authoring"]["parts"] |> hd() |> Map.fetch!("responses") |> hd()
        math = response["matchConfig"]["math"]

        assert json["itemConfig"]["type"] == "math_expression"
        assert json["itemConfig"]["subtype"] == subtype
        assert math["mode"] == mode

        if form do
          assert math["form"] == form
        end
      end
    end

    test "converts simplified fraction responses and targeted fraction feedback" do
      yaml = """
      type: oli_short_answer
      stem_md: "Enter one half as a simplified fraction."
      input_type: math_expression
      math_expression:
        subtype: simplified_fraction
      responses:
        - id: simplified
          answer: "1/2"
          score: 2
          correct: true
          feedback_id: feedback-simplified
          feedback_md: "Correct."
        - id: equivalent-fraction
          answer: "1/2"
          score: 1
          math_expression:
            subtype: fraction
          feedback_id: feedback-equivalent
          feedback_md: "Equivalent, but simplify."
        - id: incorrect
          catch_all: true
          score: 0
          feedback_id: feedback-incorrect
          feedback_md: "Incorrect."
      """

      assert {:ok, json} = ActivityConverter.from_yaml(yaml)

      assert json["inputType"] == "math_expression"

      assert json["itemConfig"] == %{
               "version" => 1,
               "type" => "math_expression",
               "subtype" => "simplified_fraction"
             }

      [simplified, equivalent, incorrect] =
        json["authoring"]["parts"] |> hd() |> Map.fetch!("responses")

      assert simplified["matchConfig"]["math"] == %{
               "mode" => "algebraic_equivalence",
               "expected" => "1/2",
               "form" => %{"type" => "simplified_fraction"}
             }

      assert equivalent["matchConfig"]["math"]["form"] == %{"type" => "fraction"}
      assert equivalent["score"] == 1
      assert equivalent["feedback"]["id"] == "feedback-equivalent"
      assert incorrect["matchConfig"] == %{"version" => 1, "type" => "always"}
    end

    test "converts expression with units, variable domains, tolerance, and unit-targeted matching" do
      yaml = """
      type: oli_short_answer
      stem_md: "Enter force."
      input_type: math_expression
      math_expression:
        subtype: expression_with_units
        validation:
          allowed_variables: ["m", "a"]
          domains:
            - variable: m
              lower: 1
              upper: 10
              integer_only: true
              preferred_values: [2, 4]
            - variable: a
              lower:
                value: 0
                inclusive: false
              upper: 20
        unit_policy:
          type: convertible_units
          units: ["N", "kg*m/s^2"]
        tolerance:
          absolute: 0.01
          relative: 0.001
      responses:
        - id: correct-force
          answer: "m*a N"
          score: 1
          correct: true
        - id: wrong-units
          answer: "m*a N"
          score: 0.5
          match_wrong_units: true
          feedback_id: feedback-wrong-units
          feedback_md: "Use the requested units."
        - id: missing-unit
          answer: "m*a N"
          score: 0.5
          match_missing_unit: true
          feedback_id: feedback-missing-unit
          feedback_md: "Include the requested units."
      """

      assert {:ok, json} = ActivityConverter.from_yaml(yaml)

      assert json["itemConfig"]["type"] == "math_expression"
      assert json["itemConfig"]["subtype"] == "expression_with_units"

      assert json["itemConfig"]["config"]["unitPolicy"] == %{
               "type" => "convertible_units",
               "units" => ["N", "kg*m/s^2"]
             }

      assert [%{"name" => "m", "integerOnly" => true}, %{"name" => "a"}] =
               json["itemConfig"]["config"]["validation"]["domains"]

      [correct, wrong_units, missing_unit, catch_all] =
        json["authoring"]["parts"] |> hd() |> Map.fetch!("responses")

      math = correct["matchConfig"]["math"]
      assert math["mode"] == "unit_aware"
      assert math["expected"] == "m*a N"
      refute Map.has_key?(math, "validation")
      refute Map.has_key?(math, "unitPolicy")

      assert math["tolerance"] == %{
               "type" => "absolute_or_relative",
               "absolute" => 0.01,
               "relative" => 0.001
             }

      assert wrong_units["matchConfig"]["math"]["matchWrongUnits"] == true
      assert missing_unit["matchConfig"]["math"]["matchMissingUnit"] == true
      assert catch_all["matchConfig"]["type"] == "always"
    end

    test "converts numeric comparison operators to the correct value field" do
      yaml = """
      type: oli_short_answer
      stem_md: "Enter a value greater than three."
      input_type: math_expression
      math_expression:
        subtype: numeric
        operator: greater_than
      responses:
        - answer: "3"
          score: 1
          correct: true
      """

      assert {:ok, json} = ActivityConverter.from_yaml(yaml)

      math =
        json["authoring"]["parts"]
        |> hd()
        |> Map.fetch!("responses")
        |> hd()
        |> get_in(["matchConfig", "math"])

      assert math == %{
               "mode" => "numeric",
               "operator" => "greater_than",
               "threshold" => "3"
             }
    end

    test "converts number with units numeric operators and tolerance" do
      yaml = """
      type: oli_short_answer
      stem_md: "Enter ten meters per second."
      input_type: math_expression
      math_expression:
        subtype: number_with_units
        unit_policy:
          type: convertible_units
          units: ["m/s", "km/hr"]
      responses:
        - answer: "10"
          score: 1
          correct: true
          math_expression:
            operator: equal
            tolerance:
              type: absolute
              value: 0.25
      """

      assert {:ok, json} = ActivityConverter.from_yaml(yaml)

      math =
        json["authoring"]["parts"]
        |> hd()
        |> Map.fetch!("responses")
        |> hd()
        |> get_in(["matchConfig", "math"])

      assert math == %{
               "mode" => "unit_aware",
               "expected" => "10",
               "operator" => "equal",
               "tolerance" => %{"type" => "absolute", "value" => 0.25}
             }
    end
  end

  describe "multi input math_expression YAML" do
    test "converts inputs, placeholders, and per-input math settings" do
      yaml = """
      type: oli_multi_input
      stem_md: "Speed {{speed}} and energy {{energy}}."
      inputs:
        - id: speed
          input_type: math_expression
          math_expression:
            subtype: number_with_units
            unit_policy:
              type: convertible_units
              units: ["m/s", "km/hr"]
          responses:
            - id: speed-correct
              answer: "10 m/s"
              score: 1
              correct: true
        - id: energy
          input_type: math_expression
          math_expression:
            subtype: expression_with_units
            validation:
              allowed_variables: ["m", "v"]
            unit_policy:
              type: convertible_units
              units: ["J", "kJ"]
          responses:
            - id: energy-correct
              answer: "0.5*m*v^2 J"
              score: 1
              correct: true
      """

      assert {:ok, json} = ActivityConverter.from_yaml(yaml)

      assert json["activityType"] == "oli_multi_input"
      assert Enum.map(json["inputs"], & &1["id"]) == ["speed", "energy"]
      assert Enum.map(json["inputs"], & &1["partId"]) == ["speed", "energy"]

      assert Enum.map(json["inputs"], & &1["itemConfig"]["subtype"]) == [
               "number_with_units",
               "expression_with_units"
             ]

      assert Enum.map(json["authoring"]["parts"], & &1["id"]) == ["speed", "energy"]

      [paragraph] = json["stem"]["content"]

      assert Enum.map(paragraph["children"], & &1["type"]) == [
               nil,
               "input_ref",
               nil,
               "input_ref",
               nil
             ]

      [speed_part, energy_part] = json["authoring"]["parts"]

      assert hd(speed_part["responses"])["matchConfig"]["math"]["mode"] == "unit_aware"
      refute Map.has_key?(hd(speed_part["responses"])["matchConfig"]["math"], "unitPolicy")

      assert Enum.at(json["inputs"], 1)["itemConfig"]["config"]["validation"][
               "allowedVariables"
             ] == ["m", "v"]

      refute Map.has_key?(hd(energy_part["responses"])["matchConfig"]["math"], "validation")
    end
  end
end
