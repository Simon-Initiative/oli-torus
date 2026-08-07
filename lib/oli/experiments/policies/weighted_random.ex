defmodule Oli.Experiments.Policies.WeightedRandom do
  @moduledoc """
  Deterministic weighted assignment policy.
  """

  @behaviour Oli.Experiments.Policies.Policy

  alias Oli.Experiments.Policies.{PolicyAssignment, PolicyUpdate}

  @version "weighted_random:v1"

  @impl true
  def assign(policy_config, _policy_state, %{
        conditions: conditions,
        assignment_key: assignment_key
      }) do
    salt = Map.get(policy_config || %{}, "salt", "default")

    total_weight =
      Enum.reduce(conditions, 0.0, fn condition, total -> total + condition.weight end)

    cond do
      conditions == [] ->
        {:error, :no_conditions}

      total_weight <= 0 ->
        {:error, :invalid_weights}

      true ->
        threshold = deterministic_threshold("#{salt}:#{assignment_key}", total_weight)
        condition = select_condition(conditions, threshold)

        {:ok,
         %PolicyAssignment{
           condition_id: condition.id,
           condition_code: condition.condition_code,
           policy_version: @version
         }}
    end
  end

  @impl true
  def record_reward(_policy_config, policy_state, _reward_context) do
    {:ok,
     %PolicyUpdate{
       algorithm_version: @version,
       previous_state: policy_state || %{},
       next_state: policy_state || %{},
       update_reason: "weighted_random_noop"
     }}
  end

  defp deterministic_threshold(input, total_weight) do
    <<integer::unsigned-64, _rest::binary>> = :crypto.hash(:sha256, input)
    total_weight * (integer / 18_446_744_073_709_551_616)
  end

  defp select_condition(conditions, threshold) do
    {condition, _running_weight} =
      Enum.reduce_while(conditions, {List.last(conditions), 0.0}, fn condition,
                                                                     {_selected, running_weight} ->
        next_weight = running_weight + condition.weight

        if threshold < next_weight do
          {:halt, {condition, next_weight}}
        else
          {:cont, {condition, next_weight}}
        end
      end)

    condition
  end
end
