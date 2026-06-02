defmodule Oli.Delivery.Evaluation.ResponseMatcherTest do
  use ExUnit.Case, async: true

  alias Oli.Activities.Model.{Part, Response}
  alias Oli.Delivery.Evaluation.{EvaluationContext, ResponseMatcher}

  defp context(input) do
    %EvaluationContext{
      resource_attempt_number: 1,
      activity_attempt_number: 1,
      activity_attempt_guid: "activity-guid",
      part_attempt_number: 1,
      part_attempt_guid: "part-guid",
      page_id: 1,
      input: input
    }
  end

  test "routes ordinary responses through the existing rule evaluator" do
    response = %Response{id: "response-1", rule: "input like {answer}", score: 1}
    part = %Part{id: "part-1", input_type: "text"}

    assert ResponseMatcher.match?(response, context("answer"), part) == {:ok, true}
    assert ResponseMatcher.match?(response, context("other"), part) == {:ok, false}
  end

  test "routes matchConfig responses through the math expression matcher" do
    response = %Response{
      id: "response-1",
      match_config: %{"version" => 1, "type" => "always"},
      score: 1
    }

    part = %Part{id: "part-1", input_type: "math_expression"}

    assert ResponseMatcher.match?(response, context("anything"), part) == {:ok, true}
  end

  test "matchConfig dispatch supports algebraic equivalence exact form and units" do
    part = %Part{id: "part-1", input_type: "math_expression"}

    algebraic = %Response{
      id: "algebraic",
      match_config: %{
        "version" => 1,
        "type" => "math_expression",
        "math" => %{"mode" => "algebraic_equivalence", "expected" => "2(x+3)"}
      },
      score: 1
    }

    exact_form = %Response{
      id: "exact-form",
      match_config: %{
        "version" => 1,
        "type" => "math_expression",
        "math" => %{
          "mode" => "algebraic_equivalence",
          "expected" => "1/2",
          "form" => %{"type" => "simplified_fraction"}
        }
      },
      score: 1
    }

    units = %Response{
      id: "units",
      match_config: %{
        "version" => 1,
        "type" => "math_expression",
        "math" => %{
          "mode" => "unit_aware",
          "expected" => "10 m/s",
          "unitPolicy" => %{"type" => "convertible_units", "units" => ["m/s", "km/hr"]}
        }
      },
      score: 1
    }

    assert ResponseMatcher.match?(algebraic, context("2x+6"), part) == {:ok, true}
    assert ResponseMatcher.match?(algebraic, context("2x+7"), part) == {:ok, false}
    assert ResponseMatcher.match?(exact_form, context("1/2"), part) == {:ok, true}
    assert ResponseMatcher.match?(exact_form, context("2/4"), part) == {:ok, false}
    assert ResponseMatcher.match?(units, context("36 km/hr"), part) == {:ok, true}
    assert ResponseMatcher.match?(units, context("35 km/hr"), part) == {:ok, false}
  end

  test "matchConfig dispatch supports targeted wrong-unit responses" do
    part = %Part{id: "part-1", input_type: "math_expression"}

    response = %Response{
      id: "wrong-units",
      match_config: %{
        "version" => 1,
        "type" => "math_expression",
        "math" => %{
          "mode" => "unit_aware",
          "expected" => "10 m/s",
          "unitPolicy" => %{"type" => "convertible_units", "units" => ["m/s", "cm/s"]},
          "matchWrongUnits" => true
        }
      },
      score: 1
    }

    assert ResponseMatcher.match?(response, context("10 cm/s"), part) == {:ok, true}
    assert ResponseMatcher.match?(response, context("9 cm/s"), part) == {:ok, false}
    assert ResponseMatcher.match?(response, context("10 m/s"), part) == {:ok, false}
    assert ResponseMatcher.match?(response, context("10"), part) == {:ok, false}
  end

  test "matchConfig dispatch supports targeted missing-unit responses" do
    part = %Part{id: "part-1", input_type: "math_expression"}

    response = %Response{
      id: "missing-units",
      match_config: %{
        "version" => 1,
        "type" => "math_expression",
        "math" => %{
          "mode" => "unit_aware",
          "expected" => "10 m/s",
          "unitPolicy" => %{"type" => "convertible_units", "units" => ["m/s", "cm/s"]},
          "matchMissingUnit" => true
        }
      },
      score: 1
    }

    assert ResponseMatcher.match?(response, context("10"), part) == {:ok, true}
    assert ResponseMatcher.match?(response, context("9"), part) == {:ok, false}
    assert ResponseMatcher.match?(response, context("10 cm/s"), part) == {:ok, false}
    assert ResponseMatcher.match?(response, context("10 m/s"), part) == {:ok, false}
  end

  test "merges item-level algebraic validation into sparse response matchConfig" do
    part = %Part{
      id: "part-1",
      input_type: "math_expression",
      item_config: %{
        "version" => 1,
        "type" => "math_expression",
        "subtype" => "algebraic",
        "config" => %{
          "validation" => %{
            "allowedVariables" => ["x"],
            "domains" => [
              %{
                "name" => "x",
                "lower" => %{"value" => -10, "inclusive" => true},
                "upper" => %{"value" => 10, "inclusive" => true},
                "exclusions" => [],
                "integerOnly" => false,
                "preferredValues" => []
              }
            ]
          }
        }
      }
    }

    response = %Response{
      id: "algebraic",
      match_config: %{
        "version" => 1,
        "type" => "math_expression",
        "math" => %{"mode" => "algebraic_equivalence", "expected" => "2(x + 3)"}
      },
      score: 1
    }

    assert ResponseMatcher.match?(response, context("2x + 6"), part) == {:ok, true}
    assert ResponseMatcher.match?(response, context("2x + 7"), part) == {:ok, false}
  end

  test "uses item-level validation and units for expression-with-units matchConfig" do
    part = %Part{
      id: "part-1",
      input_type: "math_expression",
      item_config: %{
        "version" => 1,
        "type" => "math_expression",
        "subtype" => "expression_with_units",
        "config" => %{
          "unitPolicy" => %{
            "type" => "convertible_units",
            "units" => ["m/s", "km/hr"]
          },
          "validation" => %{
            "allowedVariables" => ["x"],
            "domains" => [
              %{
                "name" => "x",
                "lower" => %{"value" => -10, "inclusive" => true},
                "upper" => %{"value" => 10, "inclusive" => true},
                "exclusions" => [],
                "integerOnly" => false,
                "preferredValues" => []
              }
            ]
          }
        }
      }
    }

    response = %Response{
      id: "expression-with-units",
      match_config: %{
        "version" => 1,
        "type" => "math_expression",
        "math" => %{"mode" => "unit_aware", "expected" => "3x m/s"}
      },
      score: 1
    }

    assert ResponseMatcher.match?(response, context("3x m/s"), part) == {:ok, true}
    assert ResponseMatcher.match?(response, context("10.8x km/hr"), part) == {:ok, true}
    assert ResponseMatcher.match?(response, context("4x m/s"), part) == {:ok, false}
  end

  test "does not evaluate stale rules when invalid matchConfig is present" do
    response = %Response{
      id: "response-1",
      rule: "input like {.*}",
      match_config: %{"version" => 2, "type" => "always"},
      score: 1
    }

    part = %Part{id: "part-1", input_type: "math_expression"}

    assert {:error, {:unsupported_version, 2}} =
             ResponseMatcher.match?(response, context("anything"), part)
  end
end
