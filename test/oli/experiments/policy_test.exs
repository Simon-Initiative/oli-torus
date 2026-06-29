defmodule Oli.Experiments.PolicyTest do
  use ExUnit.Case, async: true

  alias Oli.Experiments.Policies.{ThompsonSampling, WeightedRandom}

  describe "weighted deterministic random policy" do
    test "returns a stable assignment for the same assignment key" do
      context = %{conditions: conditions(), assignment_key: "experiment:decision:enrollment"}

      assert {:ok, first} = WeightedRandom.assign(%{"salt" => "stable"}, nil, context)
      assert {:ok, second} = WeightedRandom.assign(%{"salt" => "stable"}, nil, context)

      assert first.condition_id == second.condition_id
      assert first.condition_code == second.condition_code
      assert first.policy_version == "weighted_random:v1"
    end

    test "selects across weighted conditions for different keys" do
      selected_codes =
        1..100
        |> Enum.map(fn index ->
          {:ok, assignment} =
            WeightedRandom.assign(%{"salt" => "stable"}, nil, %{
              conditions: conditions(),
              assignment_key: "key:#{index}"
            })

          assignment.condition_code
        end)
        |> MapSet.new()

      assert MapSet.subset?(selected_codes, MapSet.new(["a", "b"]))
      assert MapSet.size(selected_codes) == 2
    end
  end

  describe "Thompson Sampling policy" do
    test "accepts binary rewards and produces auditable posterior updates" do
      assert {:ok, update} =
               ThompsonSampling.record_reward(%{}, %{}, %{
                 condition_code: "a",
                 reward_value: 1.0
               })

      assert update.algorithm_version == "thompson_sampling:v1"
      assert update.previous_state == %{}
      assert update.next_state == %{"a" => %{"successes" => 1, "failures" => 0}}
      assert update.counters == %{reward_success_count: 1, reward_failure_count: 0}
    end
  end

  defp conditions do
    [
      %{id: 1, condition_code: "a", weight: 1.0},
      %{id: 2, condition_code: "b", weight: 1.0}
    ]
  end
end
