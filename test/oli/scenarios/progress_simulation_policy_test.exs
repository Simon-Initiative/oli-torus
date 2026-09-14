defmodule Oli.Scenarios.ProgressSimulationPolicyTest do
  use ExUnit.Case, async: true

  alias Oli.Scenarios.ProgressSimulation.{Policy, Profiles, Responses}

  test "resolves immutable profiles with the small behavior contract" do
    assert Profiles.names() == [
             "high_proficiency",
             "steady_learner",
             "persistent_learner",
             "low_engagement"
           ]

    assert {:ok, profile} = Profiles.resolve("high_proficiency")

    assert Map.keys(Map.delete(profile, :name)) |> Enum.sort() ==
             Enum.sort([
               :course_reach,
               :activity_participation,
               :initial_correctness,
               :practice_attempts,
               :assessment_attempts,
               :improvement_per_attempt
             ])
  end

  test "rejects unknown profiles" do
    assert {:error, _} = Profiles.resolve("unknown")
  end

  test "accepts only fast and paced timing modes" do
    assert {:ok, :fast} = Profiles.normalize_mode(nil)
    assert {:ok, :paced} = Profiles.normalize_mode(%{"mode" => "paced"})
    assert {:error, _} = Profiles.normalize_mode(%{"mode" => "accelerated"})
  end

  test "every built-in profile uses realistic millisecond timing bounds" do
    for name <- Profiles.names() do
      timing = Profiles.timing(name)

      assert {start_min, _, start_max} = timing.start_delay
      assert start_min >= 0
      assert start_max >= 600_000

      assert {page_min, _, page_max} = timing.page_time
      assert page_min >= 600_000
      assert page_max >= page_min

      assert {answer_min, _, _} = timing.answer_time
      assert answer_min >= 15_000

      assert {retry_min, _, _} = timing.retry_delay
      assert retry_min >= 60_000

      assert {break_min, _, _} = timing.break_duration
      assert break_min >= 300_000

      assert {gap_min, _, _} = timing.session_gap
      assert gap_min >= 7_200_000
    end
  end

  test "seeded traits and timing are stable and independently keyed" do
    assert {:ok, profile} = Profiles.resolve("persistent_learner")

    assert Policy.learner_traits(profile, 42, "learner-a") ==
             Policy.learner_traits(profile, 42, "learner-a")

    refute Policy.learner_traits(profile, 42, "learner-a") ==
             Policy.learner_traits(profile, 42, "learner-b")

    for key <- 1..100 do
      assert Policy.triangular({60_000, 90_000, 180_000}, key) in 60_000..180_000
      assert Policy.paced_triangular({60_000, 90_000, 180_000}, 0.0, key) in 60_000..180_000
      assert Policy.paced_triangular({60_000, 90_000, 180_000}, 1.0, key) in 60_000..180_000
    end
  end

  test "participation, improvement, and stopping decisions are bounded and deterministic" do
    assert Policy.pages_to_visit(10, 0.0) == 0
    assert Policy.pages_to_visit(10, 0.01) == 1
    assert Policy.pages_to_visit(10, 0.5) == 5
    assert Policy.pages_to_visit(10, 1.0) == 10

    profile = %{improvement_per_attempt: 0.2}
    traits = %{correctness: 0.1}

    assert Policy.correctness(traits, profile, 1) == 0.1
    assert Policy.correctness(traits, profile, 3) == 0.5
    assert Policy.correctness(traits, profile, 100) == 0.98

    refute Policy.take?(0.0, 42, "learner", :participation)
    assert Policy.take?(1.0, 42, "learner", :retry)

    participation_decisions =
      for learner <- 1..1_000 do
        Policy.take?(0.6, 42, "learner-#{learner}", :participation)
      end

    assert Enum.count(participation_decisions, & &1) in 550..650

    assert participation_decisions ==
             (for learner <- 1..1_000 do
                Policy.take?(0.6, 42, "learner-#{learner}", :participation)
              end)

    retry_decisions =
      for learner <- 1..1_000 do
        Policy.take?(0.6, 42, "learner-#{learner}", :retry)
      end

    refute participation_decisions == retry_decisions
  end

  test "resamples a deterministic page capacity for every new learner session" do
    limits =
      Enum.map(0..7, fn ordinal ->
        Policy.session_page_limit({1, 4}, 42, "learner-a", ordinal)
      end)

    assert limits ==
             Enum.map(0..7, fn ordinal ->
               Policy.session_page_limit({1, 4}, 42, "learner-a", ordinal)
             end)

    assert Enum.all?(limits, &(&1 in 1..4))
    assert Enum.uniq(limits) |> length() > 1

    refute limits ==
             Enum.map(0..7, fn ordinal ->
               Policy.session_page_limit({1, 4}, 42, "learner-b", ordinal)
             end)
  end

  test "incorrect native choice responses remain values a learner UI can submit" do
    activity = %{
      resource_id: 9,
      content: %{
        "choices" => [%{"id" => "a"}, %{"id" => "b"}],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [
                %{"rule" => "input like {b}", "score" => 1},
                %{"rule" => "input like {.*}", "score" => 0}
              ]
            }
          ]
        }
      }
    }

    assert {:ok, %{input: "a"}} =
             Responses.for_part("oli_multiple_choice", "1", activity, 0.0, :incorrect)
  end

  test "does not fabricate an answer when a positive response rule is unsupported" do
    activity = %{
      resource_id: 10,
      content: %{
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [
                %{"rule" => "input regex {^[A-Z]+$}", "score" => 1},
                %{"rule" => "input like {.*}", "score" => 0}
              ]
            }
          ]
        }
      }
    }

    assert {:unsupported, {:response_rule, "oli_short_answer", "1"}} =
             Responses.for_part("oli_short_answer", "1", activity, 0.0, :unsupported)
  end

  test "incorrect text responses do not accidentally satisfy contains rules" do
    activity = %{
      resource_id: 11,
      content: %{
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [
                %{"rule" => "input contains {scenario}", "score" => 1},
                %{"rule" => "input like {.*}", "score" => 0}
              ]
            }
          ]
        }
      }
    }

    assert {:ok, %{input: input}} =
             Responses.for_part("oli_short_answer", "1", activity, 0.0, :incorrect)

    refute String.contains?(String.downcase(input), "scenario")
  end
end
