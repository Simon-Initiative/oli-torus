defmodule Oli.Delivery.TestModeTest do
  use ExUnit.Case, async: true
  alias Oli.Delivery.Attempts.ActivityLifecycle
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Delivery.Evaluation.Actions.FeedbackAction
  alias Oli.Delivery.Evaluation.Actions.SubmissionAction

  defp as_revision(id, model) do
    %Oli.Resources.Revision{
      id: id,
      resource_id: id,
      content: model
    }
  end

  describe "test mode evaluation and transformation" do
    setup do
      # all we need is the definition of an activity model
      %{
        content: %{
          "stem" => "",
          "choices" => [
            %{id: "1", content: []},
            %{id: "2", content: []},
            %{id: "3", content: []},
            %{id: "4", content: []}
          ],
          "authoring" => %{
            "parts" => [
              %{
                "id" => "1",
                "responses" => [
                  %{
                    "rule" => "input like {a}",
                    "score" => 10,
                    "id" => "r1",
                    "feedback" => %{"id" => "1", "content" => "yes"}
                  },
                  %{
                    "rule" => "input like {b}",
                    "score" => 1,
                    "id" => "r2",
                    "feedback" => %{"id" => "2", "content" => "almost"}
                  },
                  %{
                    "rule" => "input like {c}",
                    "score" => 0,
                    "id" => "r3",
                    "feedback" => %{"id" => "3", "content" => "no"}
                  }
                ],
                "scoringStrategy" => "best",
                "evaluationStrategy" => "regex"
              },
              %{
                "id" => "2",
                "gradingApproach" => "manual",
                "responses" => [
                  %{
                    "rule" => "input like {a}",
                    "score" => 2,
                    "id" => "r1",
                    "feedback" => %{"id" => "4", "content" => "yes"}
                  },
                  %{
                    "rule" => "input like {b}",
                    "score" => 1,
                    "id" => "r2",
                    "feedback" => %{"id" => "5", "content" => "almost"}
                  },
                  %{
                    "rule" => "input like {c}",
                    "score" => 0,
                    "id" => "r3",
                    "feedback" => %{"id" => "6", "content" => "no"}
                  }
                ],
                "scoringStrategy" => "best",
                "evaluationStrategy" => "regex"
              }
            ],
            "transformations" => [
              %{"id" => "1", "path" => "choices", "operation" => "shuffle"}
            ]
          }
        }
      }
    end

    test "performing evaulations", %{content: content} do
      part_inputs = [
        %{part_id: "1", input: %StudentInput{input: "a"}}
      ]

      assert {:ok, [%FeedbackAction{part_id: "1", score: _, out_of: _, feedback: _}]} =
               Evaluate.evaluate_from_preview(content, part_inputs)

      part_inputs = [
        %{part_id: "1", input: %StudentInput{input: "a"}},
        %{part_id: "2", input: %StudentInput{input: "b"}}
      ]

      assert {:ok,
              [
                %FeedbackAction{part_id: "1", score: _, out_of: _, feedback: _},
                %SubmissionAction{part_id: "2"}
              ]} = Evaluate.evaluate_from_preview(content, part_inputs)
    end

    test "performing a transformation", %{content: content} do
      assert {:ok, %{"stem" => _, "authoring" => _, "choices" => _}} =
               as_revision(1, content)
               |> ActivityLifecycle.perform_test_transformation()
    end

    test "performing evaluations where one is a non-matching input", %{content: content} do
      part_inputs = [
        %{part_id: "1", input: %StudentInput{input: "not present"}},
        %{part_id: "2", input: %StudentInput{input: "b"}}
      ]

      assert {:ok,
              [
                # Finding no matching response marks the answer as incorrect
                # with out_of being the highest of any response considered
                %FeedbackAction{part_id: "1", score: 0, out_of: 10.0, feedback: _},
                %SubmissionAction{part_id: "2"}
              ]} = Evaluate.evaluate_from_preview(content, part_inputs)
    end
  end
end
