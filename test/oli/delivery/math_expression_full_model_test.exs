defmodule Oli.Delivery.MathExpressionFullModelTest do
  use Oli.DataCase

  alias Ecto.Changeset
  alias Oli.Activities.Model
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Delivery.Evaluation.Actions.FeedbackAction
  alias Oli.Delivery.Evaluation.{EvaluationContext, MathExpressionMatcher, Standard}
  alias Oli.Resources.Revision

  import Oli.Factory

  setup do
    ensure_activity_registration("oli_short_answer", "Short Answer")
    ensure_activity_registration("oli_multi_input", "Multi Input")

    :ok
  end

  test "short answer full model evaluates matchConfig responses through preview and standard delivery paths" do
    model = short_answer_model()

    assert {:ok, %Model{parts: [part]}} = Model.parse(model)
    assert part.input_type == "math_expression"
    assert [%{match_config: %{"type" => "math_expression"}}, _, _] = part.responses

    assert {:ok, [%FeedbackAction{} = preview_result]} =
             Evaluate.evaluate_from_preview(model, [
               %{part_id: "fraction", input: %StudentInput{input: "2/4"}}
             ])

    assert preview_result.score == 1
    assert preview_result.out_of == 2
    assert preview_result.feedback.id == "feedback-equivalent"

    context = evaluation_context("fraction", "1/2")

    assert {:ok, %FeedbackAction{} = delivery_result} =
             Standard.perform("attempt-fraction", context, part, 1.0)

    assert delivery_result.score == 2
    assert delivery_result.out_of == 2
    assert delivery_result.feedback.id == "feedback-simplified"
  end

  test "multi input full model annotates math_expression parts and evaluates unit-aware configs" do
    model = multi_input_model()

    assert {:ok, %Model{parts: parts}} = Model.parse(model)

    assert Enum.map(parts, &{&1.id, &1.input_type}) == [
             {"speed", "math_expression"},
             {"energy", "math_expression"}
           ]

    assert {:ok, results} =
             Evaluate.evaluate_from_preview(model, [
               %{part_id: "speed", input: %StudentInput{input: "36 km/hr"}},
               %{part_id: "energy", input: %StudentInput{input: "1 kJ"}}
             ])

    assert Enum.map(results, &{&1.part_id, &1.score, &1.feedback.id}) == [
             {"speed", 1, "feedback-speed-correct"},
             {"energy", 1, "feedback-energy-correct"}
           ]
  end

  test "revision content map shape preserves matchConfig and reparses after save-style round trip" do
    model = short_answer_model()

    save_update = %{
      "content" => Map.drop(model, ["authoring"]),
      "authoring" => Map.fetch!(model, "authoring")
    }

    revision =
      %Revision{
        title: "Math expression activity",
        deleted: false,
        author_id: 1,
        resource_id: 1,
        resource_type_id: 1
      }
      |> Revision.changeset(%{
        "content" => Map.put(save_update["content"], "authoring", save_update["authoring"])
      })
      |> then(fn changeset ->
        assert changeset.valid?
        Changeset.apply_changes(changeset)
      end)

    saved_response =
      revision.content
      |> get_in(["authoring", "parts", Access.at(0), "responses", Access.at(0)])

    assert saved_response["matchConfig"]["math"]["form"]["type"] == "simplified_fraction"
    refute Map.has_key?(saved_response, "rule")

    assert {:ok, %Model{parts: [part]}} = Model.parse(revision.content)
    assert part.input_type == "math_expression"
    assert hd(part.responses).match_config == saved_response["matchConfig"]

    assert {:ok, [%FeedbackAction{score: 2.0, feedback: %{id: "feedback-simplified"}}]} =
             Evaluate.evaluate_from_preview(revision.content, [
               %{part_id: "fraction", input: %StudentInput{input: "1/2"}}
             ])
  end

  test "test evaluation uses the same matcher path for matchConfig activity JSON" do
    activity_json = Jason.encode!(short_answer_model())

    assert {:ok, [%FeedbackAction{} = evaluation]} =
             Evaluate.perform_test_eval(activity_json, "oli_short_answer", [
               %{"part_id" => "fraction", "input" => "1/2"}
             ])

    assert evaluation.part_id == "fraction"
    assert evaluation.score == 2
    assert evaluation.feedback.id == "feedback-simplified"
  end

  test "math expression matcher can require exact normalized algebraic answers" do
    exact_config = %{
      "version" => 1,
      "type" => "math_expression",
      "math" => %{
        "mode" => "algebraic_equivalence",
        "expected" => "2(x+1)",
        "expressionMatch" => "exact"
      }
    }

    equivalent_config = put_in(exact_config, ["math", "expressionMatch"], "equivalent")

    assert MathExpressionMatcher.evaluate(equivalent_config, "2x + 2") == {:ok, true}
    assert MathExpressionMatcher.evaluate(exact_config, "2(x + 1)") == {:ok, true}
    assert MathExpressionMatcher.evaluate(exact_config, "2x + 2") == {:ok, false}
  end

  test "invalid math submissions return authored fallback feedback without math diagnostics" do
    model = short_answer_model()

    assert {:ok, [%FeedbackAction{} = result]} =
             Evaluate.evaluate_from_preview(model, [
               %{part_id: "fraction", input: %StudentInput{input: "1 +"}}
             ])

    assert result.score == 0
    assert result.error == nil
    assert result.feedback.id == "feedback-incorrect"

    rendered_result = inspect(result)

    refute rendered_result =~ "1 +"
    refute rendered_result =~ "AlgebraicEquivalenceResult"
    refute rendered_result =~ "parse"
  end

  test "short answer algebraic model uses item-level variable domains for sparse response configs" do
    model = algebraic_short_answer_model()

    assert {:ok, %Model{parts: [part]}} = Model.parse(model)
    assert part.input_type == "math_expression"
    assert part.item_config["config"]["validation"]["allowedVariables"] == ["x"]
    refute Map.has_key?(hd(part.responses).match_config["math"], "validation")

    assert {:ok, [%FeedbackAction{} = result]} =
             Evaluate.evaluate_from_preview(model, [
               %{part_id: "1", input: %StudentInput{input: "2x + 6"}}
             ])

    assert result.score == 1
    assert result.feedback.id == "feedback-correct"

    assert {:ok, [%FeedbackAction{} = fallback_result]} =
             Evaluate.evaluate_from_preview(model, [
               %{part_id: "1", input: %StudentInput{input: "2x + 7"}}
             ])

    assert fallback_result.score == 0
    assert fallback_result.feedback.id == "feedback-incorrect"
  end

  test "short answer expression-with-units model evaluates variable expressions through item config" do
    model = expression_with_units_short_answer_model()

    assert {:ok, %Model{parts: [part]}} = Model.parse(model)
    assert part.input_type == "math_expression"
    assert part.item_config["subtype"] == "expression_with_units"
    refute Map.has_key?(hd(part.responses).match_config["math"], "validation")

    assert {:ok, [%FeedbackAction{} = same_units]} =
             Evaluate.evaluate_from_preview(model, [
               %{part_id: "1", input: %StudentInput{input: "3x m/s"}}
             ])

    assert same_units.score == 1
    assert same_units.feedback.id == "feedback-correct"

    assert {:ok, [%FeedbackAction{} = converted_units]} =
             Evaluate.evaluate_from_preview(model, [
               %{part_id: "1", input: %StudentInput{input: "10.8x km/hr"}}
             ])

    assert converted_units.score == 1
    assert converted_units.feedback.id == "feedback-correct"

    assert {:ok, [%FeedbackAction{} = fallback_result]} =
             Evaluate.evaluate_from_preview(model, [
               %{part_id: "1", input: %StudentInput{input: "4x m/s"}}
             ])

    assert fallback_result.score == 0
    assert fallback_result.feedback.id == "feedback-incorrect"
  end

  test "part-level sampling config is merged into unit-aware algebraic response configs" do
    model = expression_with_units_sampling_only_model()

    assert {:ok, %Model{parts: [part]}} = Model.parse(model)
    assert part.item_config["config"]["sampling"]["seed"] == 12_345
    refute Map.has_key?(hd(part.responses).match_config["math"], "sampling")
    refute Map.has_key?(hd(part.responses).match_config["math"], "validation")

    assert {:ok, [%FeedbackAction{} = result]} =
             Evaluate.evaluate_from_preview(model, [
               %{part_id: "1", input: %StudentInput{input: "2x + 6 m"}}
             ])

    assert result.score == 1
    assert result.feedback.id == "feedback-correct"
  end

  test "short answer unit-aware targeted feedback can match correct value with wrong units" do
    model = number_with_units_targeted_model()

    assert {:ok, [%FeedbackAction{} = correct_result]} =
             Evaluate.evaluate_from_preview(model, [
               %{part_id: "1", input: %StudentInput{input: "10 m/s"}}
             ])

    assert correct_result.score == 2
    assert correct_result.feedback.id == "feedback-correct"

    assert {:ok, [%FeedbackAction{} = wrong_units_result]} =
             Evaluate.evaluate_from_preview(model, [
               %{part_id: "1", input: %StudentInput{input: "10 cm/s"}}
             ])

    assert wrong_units_result.score == 1
    assert wrong_units_result.feedback.id == "feedback-wrong-units"

    assert {:ok, [%FeedbackAction{} = missing_unit_result]} =
             Evaluate.evaluate_from_preview(model, [
               %{part_id: "1", input: %StudentInput{input: "10"}}
             ])

    assert missing_unit_result.score == 1
    assert missing_unit_result.feedback.id == "feedback-missing-unit"

    assert {:ok, [%FeedbackAction{} = fallback_result]} =
             Evaluate.evaluate_from_preview(model, [
               %{part_id: "1", input: %StudentInput{input: "9 cm/s"}}
             ])

    assert fallback_result.score == 0
    assert fallback_result.feedback.id == "feedback-incorrect"
  end

  defp ensure_activity_registration(slug, title) do
    unless Oli.Activities.get_registration_by_slug(slug) do
      insert(:activity_registration, %{slug: slug, title: title})
    end
  end

  defp short_answer_model do
    %{
      "inputType" => "math_expression",
      "stem" => slate_block("Simplify one half."),
      "authoring" => %{
        "parts" => [
          %{
            "id" => "fraction",
            "gradingApproach" => "automatic",
            "responses" => [
              %{
                "id" => "response-simplified",
                "matchConfig" => %{
                  "version" => 1,
                  "type" => "math_expression",
                  "math" => %{
                    "mode" => "algebraic_equivalence",
                    "expected" => "1/2",
                    "form" => %{"type" => "simplified_fraction"}
                  }
                },
                "score" => 2,
                "feedback" => feedback("feedback-simplified", "Correct.")
              },
              %{
                "id" => "response-equivalent",
                "matchConfig" => %{
                  "version" => 1,
                  "type" => "math_expression",
                  "math" => %{"mode" => "algebraic_equivalence", "expected" => "1/2"}
                },
                "score" => 1,
                "feedback" => feedback("feedback-equivalent", "Equivalent, but simplify it.")
              },
              %{
                "id" => "response-incorrect",
                "matchConfig" => %{"version" => 1, "type" => "always"},
                "score" => 0,
                "feedback" => feedback("feedback-incorrect", "Incorrect.")
              }
            ],
            "scoringStrategy" => "best"
          }
        ],
        "transformations" => []
      }
    }
  end

  defp algebraic_short_answer_model do
    %{
      "inputType" => "math_expression",
      "itemConfig" => %{
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
      },
      "stem" => slate_block("What is 2x + 6 factored?"),
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1",
            "gradingApproach" => "automatic",
            "responses" => [
              %{
                "id" => "response-correct",
                "correct" => true,
                "matchConfig" => %{
                  "version" => 1,
                  "type" => "math_expression",
                  "math" => %{
                    "mode" => "algebraic_equivalence",
                    "expected" => "2(x + 3)"
                  }
                },
                "score" => 1,
                "feedback" => feedback("feedback-correct", "Correct.")
              },
              always_response("response-incorrect", "feedback-incorrect")
            ],
            "scoringStrategy" => "average"
          }
        ],
        "transformations" => []
      }
    }
  end

  defp expression_with_units_short_answer_model do
    %{
      "inputType" => "math_expression",
      "itemConfig" => %{
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
      },
      "stem" => slate_block("Enter 3x m/s."),
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1",
            "gradingApproach" => "automatic",
            "responses" => [
              %{
                "id" => "response-correct",
                "correct" => true,
                "matchConfig" => %{
                  "version" => 1,
                  "type" => "math_expression",
                  "math" => %{
                    "mode" => "unit_aware",
                    "expected" => "3x m/s"
                  }
                },
                "score" => 1,
                "feedback" => feedback("feedback-correct", "Correct.")
              },
              always_response("response-incorrect", "feedback-incorrect")
            ],
            "scoringStrategy" => "average"
          }
        ],
        "transformations" => []
      }
    }
  end

  defp expression_with_units_sampling_only_model do
    %{
      "inputType" => "math_expression",
      "itemConfig" => %{
        "version" => 1,
        "type" => "math_expression",
        "subtype" => "expression_with_units",
        "config" => %{
          "unitPolicy" => %{
            "type" => "convertible_units",
            "units" => ["m"]
          },
          "sampling" => %{
            "seed" => 12_345,
            "desiredCount" => 8,
            "maxAttempts" => 16,
            "includeSpecialPoints" => false
          }
        }
      },
      "stem" => slate_block("Enter 2x + 6 m."),
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1",
            "gradingApproach" => "automatic",
            "responses" => [
              %{
                "id" => "response-correct",
                "correct" => true,
                "matchConfig" => %{
                  "version" => 1,
                  "type" => "math_expression",
                  "math" => %{
                    "mode" => "unit_aware",
                    "expected" => "2(x + 3) m"
                  }
                },
                "score" => 1,
                "feedback" => feedback("feedback-correct", "Correct.")
              },
              always_response("response-incorrect", "feedback-incorrect")
            ],
            "scoringStrategy" => "average"
          }
        ],
        "transformations" => []
      }
    }
  end

  defp number_with_units_targeted_model do
    %{
      "inputType" => "math_expression",
      "itemConfig" => %{
        "version" => 1,
        "type" => "math_expression",
        "subtype" => "number_with_units",
        "config" => %{
          "unitPolicy" => %{
            "type" => "convertible_units",
            "units" => ["m/s", "cm/s"]
          }
        }
      },
      "stem" => slate_block("Enter 10 m/s."),
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1",
            "gradingApproach" => "automatic",
            "responses" => [
              %{
                "id" => "response-correct",
                "correct" => true,
                "matchConfig" => %{
                  "version" => 1,
                  "type" => "math_expression",
                  "math" => %{
                    "mode" => "unit_aware",
                    "expected" => "10 m/s"
                  }
                },
                "score" => 2,
                "feedback" => feedback("feedback-correct", "Correct.")
              },
              %{
                "id" => "response-wrong-units",
                "matchConfig" => %{
                  "version" => 1,
                  "type" => "math_expression",
                  "math" => %{
                    "mode" => "unit_aware",
                    "expected" => "10 m/s",
                    "matchWrongUnits" => true
                  }
                },
                "score" => 1,
                "feedback" => feedback("feedback-wrong-units", "Use the requested units.")
              },
              %{
                "id" => "response-missing-unit",
                "matchConfig" => %{
                  "version" => 1,
                  "type" => "math_expression",
                  "math" => %{
                    "mode" => "unit_aware",
                    "expected" => "10 m/s",
                    "matchMissingUnit" => true
                  }
                },
                "score" => 1,
                "feedback" => feedback("feedback-missing-unit", "Include units.")
              },
              always_response("response-incorrect", "feedback-incorrect")
            ],
            "scoringStrategy" => "best"
          }
        ],
        "transformations" => []
      }
    }
  end

  defp multi_input_model do
    %{
      "inputs" => [
        %{"id" => "speed-input", "partId" => "speed", "inputType" => "math_expression"},
        %{"id" => "energy-input", "partId" => "energy", "inputType" => "math_expression"}
      ],
      "stem" => slate_block("Enter speed and energy."),
      "authoring" => %{
        "parts" => [
          %{
            "id" => "speed",
            "gradingApproach" => "automatic",
            "responses" => [
              %{
                "id" => "speed-correct",
                "matchConfig" => %{
                  "version" => 1,
                  "type" => "math_expression",
                  "math" => %{
                    "mode" => "unit_aware",
                    "expected" => "10 m/s",
                    "unitPolicy" => %{
                      "type" => "convertible_units",
                      "units" => ["m/s", "km/hr"]
                    }
                  }
                },
                "score" => 1,
                "feedback" => feedback("feedback-speed-correct", "Correct speed.")
              },
              always_response("speed-incorrect", "feedback-speed-incorrect")
            ],
            "scoringStrategy" => "best"
          },
          %{
            "id" => "energy",
            "gradingApproach" => "automatic",
            "responses" => [
              %{
                "id" => "energy-correct",
                "matchConfig" => %{
                  "version" => 1,
                  "type" => "math_expression",
                  "math" => %{
                    "mode" => "unit_aware",
                    "expected" => "1000 J",
                    "unitPolicy" => %{
                      "type" => "convertible_units",
                      "units" => ["J", "kJ"]
                    }
                  }
                },
                "score" => 1,
                "feedback" => feedback("feedback-energy-correct", "Correct energy.")
              },
              always_response("energy-incorrect", "feedback-energy-incorrect")
            ],
            "scoringStrategy" => "best"
          }
        ],
        "transformations" => []
      }
    }
  end

  defp always_response(id, feedback_id) do
    %{
      "id" => id,
      "matchConfig" => %{"version" => 1, "type" => "always"},
      "score" => 0,
      "feedback" => feedback(feedback_id, "Incorrect.")
    }
  end

  defp feedback(id, text) do
    %{
      "id" => id,
      "content" => [
        %{"type" => "p", "children" => [%{"text" => text}]}
      ]
    }
  end

  defp slate_block(text) do
    %{
      "id" => "stem",
      "content" => [
        %{"type" => "p", "children" => [%{"text" => text}]}
      ]
    }
  end

  defp evaluation_context(part_id, input) do
    %EvaluationContext{
      resource_attempt_number: 1,
      activity_attempt_number: 1,
      activity_attempt_guid: "activity-guid",
      part_attempt_number: 1,
      part_attempt_guid: "attempt-#{part_id}",
      page_id: 1,
      input: input
    }
  end
end
