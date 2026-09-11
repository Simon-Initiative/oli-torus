defmodule Oli.Scenarios.ProgressSimulationTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Scenarios.ProgressSimulation

  @opts %{pct_correct: 1.0, seed: 42, user_id: 7}

  test "declares every core native activity type supported by progress simulation" do
    assert ProgressSimulation.supported_activity_types() == [
             "oli_multiple_choice",
             "oli_ordering",
             "oli_check_all_that_apply",
             "oli_short_answer",
             "oli_multi_input"
           ]
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

  defp response(slug, part_id, responses) do
    ProgressSimulation.response_for_part(slug, part_id, activity(%{part_id => responses}), @opts)
  end

  defp response(rule, score), do: %{"rule" => rule, "score" => score}

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
