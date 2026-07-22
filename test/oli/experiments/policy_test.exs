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
    test "accepts binary rewards and initializes default Beta(1,1) posterior state" do
      assert {:ok, update} =
               ThompsonSampling.record_reward(%{}, %{}, %{
                 condition_code: "a",
                 reward_value: 1.0
               })

      assert update.algorithm_version == "thompson_sampling:v2"
      assert update.previous_state == %{}

      assert update.next_state == %{
               "a" => %{
                 "prior_alpha" => 1.0,
                 "prior_beta" => 1.0,
                 "successes" => 1,
                 "failures" => 0,
                 "posterior_alpha" => 2.0,
                 "posterior_beta" => 1.0
               }
             }

      assert update.counters == %{reward_success_count: 1, reward_failure_count: 0}
    end

    test "accepts valid custom priors from policy config" do
      policy_config = %{
        "priors" => %{
          "default" => %{"alpha" => 2.0, "beta" => 3.0},
          "conditions" => %{"b" => %{"alpha" => 5.0, "beta" => 7.0}}
        }
      }

      assert {:ok, update} =
               ThompsonSampling.record_reward(policy_config, %{}, %{
                 condition_code: "b",
                 reward_value: 0.0
               })

      assert update.next_state["b"] == %{
               "prior_alpha" => 5.0,
               "prior_beta" => 7.0,
               "successes" => 0,
               "failures" => 1,
               "posterior_alpha" => 5.0,
               "posterior_beta" => 8.0
             }

      assert update.counters == %{reward_success_count: 0, reward_failure_count: 1}
    end

    test "rejects invalid priors" do
      policy_config = %{"priors" => %{"default" => %{"alpha" => 0.0, "beta" => 1.0}}}

      assert {:error, {:invalid_prior, "alpha"}} =
               ThompsonSampling.assign(policy_config, %{}, %{
                 conditions: conditions(),
                 assignment_key: "experiment:decision:enrollment"
               })

      assert {:error, {:invalid_prior, "alpha"}} =
               ThompsonSampling.record_reward(policy_config, %{}, %{
                 condition_code: "a",
                 reward_value: 1.0
               })
    end

    test "rejects priors outside the supported sampling bounds" do
      for alpha <- [0.00001, 1_000.1] do
        policy_config = %{"priors" => %{"default" => %{"alpha" => alpha, "beta" => 1.0}}}

        assert {:error, {:invalid_prior, "alpha"}} =
                 ThompsonSampling.assign(policy_config, %{}, %{
                   conditions: conditions(),
                   assignment_key: "experiment:decision:enrollment"
                 })
      end
    end

    test "rejects non-binary or non-numeric reward values" do
      for reward_value <- ["1.0", %{"value" => 1.0}, 0.5, 2.0] do
        assert {:error, :invalid_reward_value} =
                 ThompsonSampling.record_reward(%{}, %{}, %{
                   condition_code: "a",
                   reward_value: reward_value
                 })
      end
    end

    test "samples active condition posteriors and selects the highest sampled value" do
      policy_state = %{
        "a" => %{
          "prior_alpha" => 1.0,
          "prior_beta" => 1.0,
          "successes" => 3,
          "failures" => 1
        },
        "b" => %{
          "prior_alpha" => 1.0,
          "prior_beta" => 1.0,
          "successes" => 0,
          "failures" => 4
        }
      }

      sampler = fn
        4.0, 2.0, "a" -> 0.25
        1.0, 5.0, "b" -> 0.75
      end

      assert {:ok, assignment} =
               ThompsonSampling.assign(%{}, policy_state, %{
                 conditions: conditions(),
                 assignment_key: "experiment:decision:enrollment",
                 beta_sampler: sampler
               })

      assert assignment.condition_id == 2
      assert assignment.condition_code == "b"
      assert assignment.policy_version == "thompson_sampling:v2"
      assert assignment.metadata == %{posterior_sample: 0.75}
    end

    test "keeps the highest sample when a later condition samples lower" do
      sampler = fn
        _alpha, _beta, "a" -> 0.8
        _alpha, _beta, "b" -> 0.2
      end

      assert {:ok, assignment} =
               ThompsonSampling.assign(%{}, %{}, %{
                 conditions: conditions(),
                 assignment_key: "experiment:decision:enrollment",
                 beta_sampler: sampler
               })

      assert assignment.condition_code == "a"
      assert assignment.metadata == %{posterior_sample: 0.8}
    end

    test "updates only the assigned condition posterior" do
      previous_state = %{
        "a" => %{
          "prior_alpha" => 1.0,
          "prior_beta" => 1.0,
          "successes" => 2,
          "failures" => 0,
          "posterior_alpha" => 3.0,
          "posterior_beta" => 1.0
        },
        "b" => %{
          "prior_alpha" => 2.0,
          "prior_beta" => 2.0,
          "successes" => 1,
          "failures" => 3,
          "posterior_alpha" => 3.0,
          "posterior_beta" => 5.0
        }
      }

      assert {:ok, update} =
               ThompsonSampling.record_reward(%{}, previous_state, %{
                 condition_code: "b",
                 reward_value: 0.0
               })

      assert update.next_state["a"] == previous_state["a"]

      assert update.next_state["b"] == %{
               "prior_alpha" => 2.0,
               "prior_beta" => 2.0,
               "successes" => 1,
               "failures" => 4,
               "posterior_alpha" => 3.0,
               "posterior_beta" => 6.0
             }
    end
  end

  defp conditions do
    [
      %{id: 1, condition_code: "a", weight: 1.0},
      %{id: 2, condition_code: "b", weight: 1.0}
    ]
  end
end
