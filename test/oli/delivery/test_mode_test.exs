defmodule Oli.Delivery.TestModeTest do

  use ExUnit.Case, async: true

  alias Oli.Delivery.Attempts
  alias Oli.Delivery.Attempts.{StudentInput}

  describe "test mode evaluation and transformation" do

    setup do
      # all we need is the definition of an activity model
      %{content: %{
        "stem" => "1",
        "choices" => [
          %{ id: "1", content: []},
          %{ id: "2", content: []},
          %{ id: "3", content: []},
          %{ id: "4", content: []}
        ],
        "authoring" => %{
          "parts" => [
            %{"id" => "1", "responses" => [
              %{"rule" => "input like {a}", "score" => 10, "id" => "r1", "feedback" => %{"id" => "1", "content" => "yes"}},
              %{"rule" => "input like {b}", "score" => 1, "id" => "r2", "feedback" => %{"id" => "2", "content" => "almost"}},
              %{"rule" => "input like {c}", "score" => 0, "id" => "r3", "feedback" => %{"id" => "3", "content" => "no"}}
            ], "scoringStrategy" => "best", "evaluationStrategy" => "regex"},
            %{"id" => "2", "responses" => [
              %{"rule" => "input like {a}", "score" => 2, "id" => "r1", "feedback" => %{"id" => "4", "content" => "yes"}},
              %{"rule" => "input like {b}", "score" => 1, "id" => "r2", "feedback" => %{"id" => "5", "content" => "almost"}},
              %{"rule" => "input like {c}", "score" => 0, "id" => "r3", "feedback" => %{"id" => "6", "content" => "no"}}
            ], "scoringStrategy" => "best", "evaluationStrategy" => "regex"}
          ],
          "transformations" => [
            %{"id" => "1", "path" => "choices", "operation" => "shuffle"}
          ]
        }
      }}
    end

    test "performing evaulations", %{ content: content} do

      part_inputs = [
        %{part_id: "1", input: %StudentInput{input: "a"}}
      ]

      assert {:ok, [%{part_id: "1", result: _, feedback: _}]} = Attempts.perform_test_evaluation(content, part_inputs)

      part_inputs = [
        %{part_id: "1", input: %StudentInput{input: "a"}},
        %{part_id: "2", input: %StudentInput{input: "b"}}
      ]

      assert {:ok, [%{part_id: "1", result: _, feedback: _}, %{part_id: "2", result: _, feedback: _}]}
        = Attempts.perform_test_evaluation(content, part_inputs)

    end

    test "performing a transformation", %{ content: content} do
      assert {:ok, %{"stem" => _, "authoring" => _, "choices" => _}} = Attempts.perform_test_transformation(content)
    end

    test "performing evaluations where one should result in an error", %{ content: content} do

      part_inputs = [
        %{part_id: "1", input: %StudentInput{input: "not present"}},
        %{part_id: "2", input: %StudentInput{input: "b"}}
      ]

      assert {:ok, [%{part_id: "1", error: "error in evaluation"}, %{part_id: "2", result: _, feedback: _}]}
        = Attempts.perform_test_evaluation(content, part_inputs)

    end

  end

end
