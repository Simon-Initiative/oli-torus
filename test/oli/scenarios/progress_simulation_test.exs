defmodule Oli.Scenarios.ProgressSimulationTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Delivery.Evaluation.{EvaluationContext, Rule}
  alias Oli.Scenarios.ProgressSimulation
  alias Oli.Scenarios.LearnerActions

  @opts %{correctness: 1.0, seed: 42, user_id: 7}

  test "declares every core native activity type supported by progress simulation" do
    assert ProgressSimulation.supported_activity_types() == [
             "oli_multiple_choice",
             "oli_ordering",
             "oli_check_all_that_apply",
             "oli_short_answer",
             "oli_multi_input"
           ]
  end

  test "keeps the simulator's fixed safety boundary small and independent of Oban" do
    source = File.read!("lib/oli/scenarios/progress_simulation.ex")

    assert source =~ "@max_learners 100"

    assert source =~
             ":paced -> Keyword.put(stream_options, :max_concurrency, length(assignments))"

    assert source =~ ":fast -> stream_options"
    refute source =~ "@fast_max_concurrency"
    refute source =~ "Oban"
    refute source =~ "ProgressSimulation.Limits"
    refute source =~ "ActionRunner"
    refute source =~ "Cancellation"
  end

  test "builds a correct multiple choice response" do
    assert response("oli_multiple_choice", "1", [
             response("input like {choice-b}", 1),
             response("input like {.*}", 0)
           ]) == %StudentInput{input: "choice-b"}
  end

  test "builds a correct ordering response" do
    assert response("oli_ordering", "1", [
             response("input like {first second third}", 1),
             response("input like {.*}", 0)
           ]) == %StudentInput{input: "first second third"}
  end

  test "builds a correct check all that apply response" do
    assert response("oli_check_all_that_apply", "1", [
             response("input like {choice-a choice-c}", 1),
             response("input like {.*}", 0)
           ]) == %StudentInput{input: "choice-a choice-c"}
  end

  test "builds a correct single response input from a contains rule" do
    assert response("oli_short_answer", "1", [
             response("input contains {expected answer}", 1),
             response("input like {.*}", 0)
           ]) == %StudentInput{input: "expected answer"}
  end

  test "builds correct text and numeric inputs for a multi-input activity" do
    activity =
      activity(%{
        "text_part" => [
          response("input contains {answer}", 1),
          response("input like {.*}", 0)
        ],
        "numeric_part" => [
          response("input = {1}", 1),
          response("input like {.*}", 0)
        ]
      })

    assert ProgressSimulation.response_for_part(
             "oli_multi_input",
             "text_part",
             activity,
             @opts
           ) == %StudentInput{input: "answer"}

    assert ProgressSimulation.response_for_part(
             "oli_multi_input",
             "numeric_part",
             activity,
             @opts
           ) == %StudentInput{input: "1"}
  end

  test "returns nil for activity types outside the supported native set" do
    assert ProgressSimulation.response_for_part("oli_custom_dnd", "1", activity(%{}), @opts) ==
             nil
  end

  test "normalizes hierarchy activities in authored reference order" do
    hierarchy = %{
      "later" => {%{resource_id: 900, attempt_guid: "later"}, %{}},
      "first" => {%{resource_id: 100, attempt_guid: "first"}, %{}}
    }

    assert [first, later] = LearnerActions.activities(hierarchy, [100, 900])
    assert first.activity_attempt.attempt_guid == "first"
    assert later.activity_attempt.attempt_guid == "later"
  end

  test "correctness zero and one generate evaluator-confirmed native responses" do
    specs = [
      {"oli_multiple_choice", "1", choice_activity(["a", "b"], "input like {b}")},
      {"oli_ordering", "1",
       choice_activity(["first", "second", "third"], "input like {first second third}")},
      {"oli_check_all_that_apply", "1", choice_activity(["a", "b", "c"], "input like {a c}")},
      {"oli_short_answer", "1", activity(%{"1" => response_set("input contains {scenario}")})},
      {"oli_multi_input", "text_part",
       multi_input_activity(false, "text", "input contains {answer}")},
      {"oli_multi_input", "numeric_part", multi_input_activity(true, "numeric", "input = {1}")}
    ]

    for {slug, part_id, model} <- specs do
      positive_rule =
        model.content["authoring"]["parts"]
        |> Enum.find(&(&1["id"] == part_id))
        |> Map.fetch!("responses")
        |> List.first()
        |> Map.fetch!("rule")

      assert %StudentInput{input: correct} =
               ProgressSimulation.response_for_part(
                 slug,
                 part_id,
                 model,
                 %{@opts | correctness: 1.0}
               )

      assert %StudentInput{input: incorrect} =
               ProgressSimulation.response_for_part(
                 slug,
                 part_id,
                 model,
                 %{@opts | correctness: 0.0}
               )

      assert evaluates?(positive_rule, correct)
      refute evaluates?(positive_rule, incorrect)
    end
  end

  test "response generation uses the current transformed activity model" do
    activity = %{
      resource_id: 101,
      content: %{
        "authoring" => %{
          "parts" => [%{"id" => "1", "responses" => response_set("input like {stale}")}]
        }
      },
      transformed_model: %{
        "authoring" => %{
          "parts" => [%{"id" => "1", "responses" => response_set("input like {current}")}]
        }
      }
    }

    assert %StudentInput{input: "current"} =
             ProgressSimulation.response_for_part(
               "oli_short_answer",
               "1",
               activity,
               %{@opts | correctness: 1.0}
             )
  end

  defp response(slug, part_id, responses) do
    ProgressSimulation.response_for_part(slug, part_id, activity(%{part_id => responses}), @opts)
  end

  defp response(rule, score), do: %{"rule" => rule, "score" => score}

  defp response_set(rule), do: [response(rule, 1), response("input like {.*}", 0)]

  defp choice_activity(ids, rule) do
    activity(%{"1" => response_set(rule)})
    |> put_in([:content, "choices"], Enum.map(ids, &%{"id" => &1}))
  end

  defp multi_input_activity(submit_per_part, input_type, rule) do
    part_id = if input_type == "numeric", do: "numeric_part", else: "text_part"

    activity(%{part_id => response_set(rule)})
    |> put_in([:content, "submitPerPart"], submit_per_part)
    |> put_in(
      [
        :content,
        "inputs"
      ],
      [%{"partId" => part_id, "inputType" => input_type}]
    )
  end

  defp evaluates?(rule, input) do
    context = %EvaluationContext{
      resource_attempt_number: 1,
      activity_attempt_number: 1,
      part_attempt_number: 1,
      part_attempt_guid: "part",
      activity_attempt_guid: "activity",
      page_id: 1,
      input: input
    }

    {:ok, tree} = Rule.parse(rule)
    {:ok, result} = Rule.evaluate(tree, context)
    result
  end

  defp activity(parts_by_id) do
    %{
      resource_id: 101,
      content: %{
        "authoring" => %{
          "parts" =>
            Enum.map(parts_by_id, fn {id, responses} ->
              %{"id" => id, "responses" => responses}
            end)
        }
      }
    }
  end
end
