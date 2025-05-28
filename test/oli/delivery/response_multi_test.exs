defmodule Oli.Delivery.ResponseMultiTest do
  use ExUnit.Case, async: true
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Delivery.Evaluation.Actions.FeedbackAction

  describe "test mode evaluation and transformation" do
    setup do
      # all we need is the definition of an activity model
      %{
        content: %{
          "authoring" => %{
            "parts" => [
              %{
                "gradingApproach" => "automatic",
                "hints" => [
                  %{
                    "content" => [
                      %{
                        "children" => [%{"text" => ""}],
                        "id" => "1074293314",
                        "type" => "p"
                      }
                    ],
                    "editor" => "slate",
                    "id" => "453318866"
                  }
                ],
                "id" => "651271558",
                "outOf" => nil,
                "responses" => [
                  %{
                    "feedback" => %{
                      "content" => [
                        %{
                          "children" => [%{"text" => "Correct"}],
                          "id" => "4146132081",
                          "type" => "p"
                        }
                      ],
                      "editor" => "slate",
                      "id" => "3936475886"
                    },
                    "id" => "1596796291",
                    "rule" =>
                      "input_ref_1637853221 contains {answer} && input_ref_2369651067 = {1}",
                    "score" => 1
                  },
                  %{
                    "feedback" => %{
                      "content" => [
                        %{
                          "children" => [%{"text" => "It Is Incorrect"}],
                          "id" => "438504847",
                          "type" => "p"
                        }
                      ],
                      "editor" => "slate",
                      "id" => "1666885160"
                    },
                    "id" => "59027657",
                    "rule" => "input_ref_1637853221 like {.*} && input_ref_2369651067 like {.*}",
                    "score" => 0
                  }
                ],
                "scoringStrategy" => "best",
                "targets" => ["1637853221", "2369651067"]
              }
            ],
            "previewText" => "Example question with a fill in the blank . asdsds ",
            "targeted" => [],
            "transformations" => [
              %{
                "firstAttemptOnly" => true,
                "id" => "2105920908",
                "operation" => "shuffle",
                "path" => "choices"
              }
            ]
          },
          "content" => %{
            "bibrefs" => [],
            "choices" => [],
            "inputs" => [
              %{"id" => "1637853221", "inputType" => "text", "partId" => "651271558"},
              %{
                "id" => "2369651067",
                "inputType" => "numeric",
                "partId" => "651271558"
              }
            ],
            "multInputsPerPart" => true,
            "stem" => %{
              "content" => [
                %{
                  "children" => [
                    %{"text" => "Example question with a fill in the blank "},
                    %{
                      "children" => [%{"text" => ""}],
                      "id" => "1637853221",
                      "type" => "input_ref"
                    },
                    %{"text" => ". asdsds "},
                    %{
                      "children" => [%{"text" => ""}],
                      "id" => "2369651067",
                      "type" => "input_ref"
                    },
                    %{"text" => ""}
                  ],
                  "id" => "4258052183",
                  "type" => "p"
                }
              ],
              "id" => "4276466648"
            },
            "submitPerPart" => false
          },
          "objectives" => %{"651271558" => []},
          "tags" => [],
          "title" => "Multi Input"
        }
      }
    end

    test "performing evaulations", %{content: content} do
      part_inputs = [
        %{
          part_id: "651271558",
          input: %StudentInput{
            input: Poison.encode!(%{"1637853221" => "answer", "2369651067" => "1"})
          }
        }
      ]

      assert {:ok, [%FeedbackAction{part_id: "651271558", score: _, out_of: _, feedback: _}]} =
               Evaluate.evaluate_from_preview(content, part_inputs)
    end

    test "performing evaluations where one is a non-matching input", %{content: content} do
      part_inputs = [
        %{
          part_id: "651271558",
          input: %StudentInput{
            input: Poison.encode!(%{"1637853221" => "bad", "2369651067" => "1"})
          }
        }
      ]

      assert {:ok,
              [
                # Finding no matching response marks the answer as incorrect
                # with out_of being the highest of any response considered
                %FeedbackAction{part_id: "651271558", score: +0.0, out_of: 1.0, feedback: _}
              ]} = Evaluate.evaluate_from_preview(content, part_inputs)
    end
  end
end
