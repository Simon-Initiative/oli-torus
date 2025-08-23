defmodule Oli.MCP.Tools.ActivityTestEvalToolTest do
  use Oli.DataCase

  alias Oli.MCP.Tools.ActivityTestEvalTool
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate

  import Oli.Factory

  setup do
    # Ensure system roles exist before creating authors
    Oli.TestHelpers.ensure_system_roles()
    # Ensure activity registrations exist (they might already be seeded)
    unless Oli.Activities.get_registration_by_slug("oli_multiple_choice") do
      insert(:activity_registration, %{
        slug: "oli_multiple_choice",
        title: "Multiple Choice"
      })
    end

    unless Oli.Activities.get_registration_by_slug("oli_short_answer") do
      insert(:activity_registration, %{
        slug: "oli_short_answer",
        title: "Short Answer"
      })
    end

    :ok
  end

  describe "activity test evaluation tool" do
    test "evaluates multiple choice activity with correct answer" do
      activity = %{
        "stem" => %{
          "content" => [%{"type" => "p", "children" => [%{"text" => "What is 2+2?"}]}],
          "editor" => "slate",
          "id" => "stem1",
          "textDirection" => "ltr"
        },
        "choices" => [
          %{
            "content" => [%{"type" => "p", "children" => [%{"text" => "3"}]}],
            "editor" => "slate",
            "id" => "choice1",
            "textDirection" => "ltr"
          },
          %{
            "content" => [%{"type" => "p", "children" => [%{"text" => "4"}]}],
            "editor" => "slate",
            "id" => "choice2",
            "textDirection" => "ltr"
          }
        ],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "hints" => [],
              "responses" => [
                %{
                  "id" => "response1",
                  "rule" => "input like {choice2}",
                  "score" => 1,
                  "correct" => true,
                  "feedback" => %{
                    "content" => [%{"type" => "p", "children" => [%{"text" => "Correct! 2+2=4"}]}],
                    "editor" => "slate",
                    "id" => "feedback1",
                    "textDirection" => "ltr"
                  }
                },
                %{
                  "id" => "response2",
                  "rule" => "input like {.*}",
                  "score" => 0,
                  "correct" => false,
                  "feedback" => %{
                    "content" => [
                      %{"type" => "p", "children" => [%{"text" => "Incorrect. Try again."}]}
                    ],
                    "editor" => "slate",
                    "id" => "feedback2",
                    "textDirection" => "ltr"
                  }
                }
              ],
              "gradingApproach" => "automatic",
              "scoringStrategy" => "average",
              "targets" => []
            }
          ],
          "previewText" => "What is 2+2?",
          "targeted" => [],
          "transformations" => [],
          "version" => 2
        }
      }

      activity_json = Jason.encode!(activity)

      part_inputs = [
        %{
          "part_id" => "1",
          "input" => "choice2"
        }
      ]

      result = Evaluate.perform_test_eval(activity_json, "oli_short_answer", part_inputs)

      assert {:ok, evaluations} = result
      assert [evaluation] = evaluations
      assert evaluation.part_id == "1"
      assert evaluation.score == 1
    end

    test "evaluates multiple choice activity with incorrect answer" do
      activity = %{
        "stem" => %{
          "content" => [%{"type" => "p", "children" => [%{"text" => "What is 2+2?"}]}],
          "editor" => "slate",
          "id" => "stem1",
          "textDirection" => "ltr"
        },
        "choices" => [
          %{
            "content" => [%{"type" => "p", "children" => [%{"text" => "3"}]}],
            "editor" => "slate",
            "id" => "choice1",
            "textDirection" => "ltr"
          },
          %{
            "content" => [%{"type" => "p", "children" => [%{"text" => "4"}]}],
            "editor" => "slate",
            "id" => "choice2",
            "textDirection" => "ltr"
          }
        ],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "hints" => [],
              "responses" => [
                %{
                  "id" => "response1",
                  "rule" => "input like {choice2}",
                  "score" => 1,
                  "correct" => true,
                  "feedback" => %{
                    "content" => [%{"type" => "p", "children" => [%{"text" => "Correct! 2+2=4"}]}],
                    "editor" => "slate",
                    "id" => "feedback1",
                    "textDirection" => "ltr"
                  }
                },
                %{
                  "id" => "response2",
                  "rule" => "input like {.*}",
                  "score" => 0,
                  "correct" => false,
                  "feedback" => %{
                    "content" => [
                      %{"type" => "p", "children" => [%{"text" => "Incorrect. Try again."}]}
                    ],
                    "editor" => "slate",
                    "id" => "feedback2",
                    "textDirection" => "ltr"
                  }
                }
              ],
              "gradingApproach" => "automatic",
              "scoringStrategy" => "average",
              "targets" => []
            }
          ],
          "previewText" => "What is 2+2?",
          "targeted" => [],
          "transformations" => [],
          "version" => 2
        }
      }

      activity_json = Jason.encode!(activity)

      part_inputs = [
        %{
          "part_id" => "1",
          "input" => ["choice1"]
        }
      ]

      result = Evaluate.perform_test_eval(activity_json, "oli_multiple_choice", part_inputs)

      assert {:ok, evaluations} = result
      assert [evaluation] = evaluations
      assert evaluation.part_id == "1"
      assert evaluation.score == 0
    end

    test "handles invalid activity type" do
      activity = %{"invalid" => "structure"}
      activity_json = Jason.encode!(activity)
      part_inputs = [%{"part_id" => "1", "input" => %{}}]
      part_inputs_json = Jason.encode!(part_inputs)

      frame = %{}

      result =
        ActivityTestEvalTool.execute(
          %{
            activity_json: activity_json,
            activity_type: "invalid_type",
            part_inputs: part_inputs_json
          },
          frame
        )

      assert {:reply, response, ^frame} = result
      assert response.isError == true
      assert [%{"type" => "text", "text" => error_text}] = response.content
      assert String.contains?(error_text, "Test evaluation failed")
    end

    test "handles non-existent part id" do
      activity = %{
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "hints" => [],
              "responses" => [],
              "gradingApproach" => "automatic",
              "scoringStrategy" => "average",
              "targets" => []
            }
          ],
          "version" => 2
        }
      }

      activity_json = Jason.encode!(activity)

      part_inputs = [
        %{
          "part_id" => "nonexistent",
          "input" => %{}
        }
      ]

      part_inputs_json = Jason.encode!(part_inputs)

      frame = %{}

      result =
        ActivityTestEvalTool.execute(
          %{
            activity_json: activity_json,
            activity_type: "oli_multiple_choice",
            part_inputs: part_inputs_json
          },
          frame
        )

      assert {:reply, response, ^frame} = result
      assert [%{"type" => "text", "text" => text}] = response.content
      assert String.contains?(text, "Part nonexistent")
      assert String.contains?(text, "not found in activity model")
    end
  end

  describe "perform_test_eval function" do
    test "evaluates activity correctly" do
      activity = %{
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "hints" => [],
              "responses" => [
                %{
                  "id" => "response1",
                  "rule" => "input like {test}",
                  "score" => 1,
                  "correct" => true,
                  "feedback" => %{
                    "content" => [%{"type" => "p", "children" => [%{"text" => "Good job!"}]}],
                    "editor" => "slate",
                    "id" => "feedback1",
                    "textDirection" => "ltr"
                  }
                },
                %{
                  "id" => "response2",
                  "rule" => "input like {.*}",
                  "score" => 0,
                  "correct" => false,
                  "feedback" => %{
                    "content" => [%{"type" => "p", "children" => [%{"text" => "Incorrect"}]}],
                    "editor" => "slate",
                    "id" => "feedback2",
                    "textDirection" => "ltr"
                  }
                }
              ],
              "gradingApproach" => "automatic",
              "scoringStrategy" => "average",
              "targets" => []
            }
          ],
          "version" => 2
        }
      }

      activity_json = Jason.encode!(activity)

      part_inputs = [
        %{
          "part_id" => "1",
          "input" => "test"
        }
      ]

      result = Evaluate.perform_test_eval(activity_json, "oli_short_answer", part_inputs)

      assert {:ok, evaluations} = result
      assert [evaluation] = evaluations
      assert evaluation.part_id == "1"
      assert evaluation.score == 1
    end

    test "returns error for invalid JSON" do
      result = Evaluate.perform_test_eval("invalid json", "oli_multiple_choice", [])

      assert {:error, _reason} = result
    end

    test "returns error for non-existent activity type" do
      activity = %{"authoring" => %{"parts" => []}}
      activity_json = Jason.encode!(activity)

      result = Evaluate.perform_test_eval(activity_json, "nonexistent_type", [])

      assert {:error, reason} = result
      assert String.contains?(to_string(reason), "not found")
    end
  end
end
