defmodule Oli.Experiments.Policies.ThompsonSampling do
  @moduledoc """
  Thompson Sampling contract support for binary rewards.
  """

  @behaviour Oli.Experiments.Policies.Policy

  alias Oli.Experiments.Policies.{PolicyAssignment, PolicyUpdate}

  @version "thompson_sampling:v1"

  @impl true
  def assign(_policy_config, policy_state, %{conditions: conditions}) do
    case conditions do
      [] ->
        {:error, :no_conditions}

      _ ->
        condition =
          Enum.max_by(conditions, fn condition ->
            posterior_mean(policy_state || %{}, condition.condition_code)
          end)

        {:ok,
         %PolicyAssignment{
           condition_id: condition.id,
           condition_code: condition.condition_code,
           policy_version: @version
         }}
    end
  end

  @impl true
  def record_reward(_policy_config, policy_state, %{
        condition_code: condition_code,
        reward_value: reward_value
      }) do
    previous_state = policy_state || %{}

    condition_state =
      Map.get(previous_state, condition_code, %{"successes" => 0, "failures" => 0})

    {successes, failures} =
      case reward_value >= 1.0 do
        true -> {condition_state["successes"] + 1, condition_state["failures"]}
        false -> {condition_state["successes"], condition_state["failures"] + 1}
      end

    next_state =
      Map.put(previous_state, condition_code, %{
        "successes" => successes,
        "failures" => failures
      })

    {:ok,
     %PolicyUpdate{
       algorithm_version: @version,
       previous_state: previous_state,
       next_state: next_state,
       update_reason: "binary_reward",
       counters: %{
         reward_success_count: if(reward_value >= 1.0, do: 1, else: 0),
         reward_failure_count: if(reward_value >= 1.0, do: 0, else: 1)
       }
     }}
  end

  defp posterior_mean(policy_state, condition_code) do
    condition_state = Map.get(policy_state, condition_code, %{"successes" => 0, "failures" => 0})
    successes = condition_state["successes"]
    failures = condition_state["failures"]

    (successes + 1) / (successes + failures + 2)
  end
end
