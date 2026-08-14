defmodule Oli.Experiments.PolicyConfiguration do
  @moduledoc """
  Normalizes and validates experiment assignment-policy configuration.

  This module is an internal boundary used by `Oli.Experiments`; callers should use
  the context API rather than invoking it directly.
  """

  alias Oli.Experiments.ExperimentError
  alias Oli.Experiments.Policies.ThompsonSampling

  @reward_source "assessment_page:normalized_score"
  @default_guardrails %{
    "warm_up_assignments" => 0,
    "max_condition_share" => 1.0,
    "fixed_control_allocation" => nil,
    "imbalance_threshold" => 1.0
  }

  @spec default_guardrails() :: map()
  @doc false
  def default_guardrails, do: @default_guardrails

  @spec from_attrs(struct() | map()) :: map()
  @doc false
  def from_attrs(attrs) do
    %{
      "reward_source" => Map.get(attrs, :reward_source) || @reward_source,
      "priors" => %{
        "default" => %{
          "alpha" => Map.get(attrs, :prior_alpha) || 1.0,
          "beta" => Map.get(attrs, :prior_beta) || 1.0
        }
      },
      "guardrails" => %{
        "warm_up_assignments" => Map.get(attrs, :warm_up_assignments) || 0,
        "max_condition_share" => Map.get(attrs, :max_condition_share) || 1.0,
        "fixed_control_allocation" => Map.get(attrs, :fixed_control_allocation),
        "imbalance_threshold" => Map.get(attrs, :imbalance_threshold) || 1.0
      }
    }
  end

  @spec validate(atom(), term()) :: :ok | {:error, ExperimentError.t()}
  @doc false
  def validate(:weighted_random, _policy_config), do: :ok

  def validate(:thompson_sampling, policy_config) when is_map(policy_config) do
    with {:ok, normalized} <- normalize_thompson_policy_config(policy_config),
         :ok <- validate_thompson_priors(normalized),
         :ok <- validate_thompson_guardrails(normalized) do
      :ok
    end
  end

  def validate(:thompson_sampling, _policy_config),
    do: invalid_condition("Thompson Sampling policy config must be a map")

  def validate(_algorithm, _policy_config), do: :ok

  defp normalize_thompson_policy_config(policy_config) do
    defaults = ThompsonSampling.default_policy_config()

    with {:ok, priors} <- nested_map(policy_config, "priors"),
         {:ok, default_prior} <- nested_map(priors, "default"),
         :ok <- reject_condition_priors(priors),
         {:ok, guardrails} <- nested_map(policy_config, "guardrails") do
      {:ok,
       %{
         "reward_source" => Map.get(policy_config, "reward_source", @reward_source),
         "priors" => %{
           "default" => %{
             "alpha" => Map.get(default_prior, "alpha", defaults["priors"]["default"]["alpha"]),
             "beta" => Map.get(default_prior, "beta", defaults["priors"]["default"]["beta"])
           }
         },
         "guardrails" => %{
           "warm_up_assignments" =>
             Map.get(
               guardrails,
               "warm_up_assignments",
               @default_guardrails["warm_up_assignments"]
             ),
           "max_condition_share" =>
             Map.get(
               guardrails,
               "max_condition_share",
               @default_guardrails["max_condition_share"]
             ),
           "fixed_control_allocation" =>
             Map.get(
               guardrails,
               "fixed_control_allocation",
               @default_guardrails["fixed_control_allocation"]
             ),
           "imbalance_threshold" =>
             Map.get(
               guardrails,
               "imbalance_threshold",
               @default_guardrails["imbalance_threshold"]
             )
         }
       }}
    end
  end

  defp nested_map(map, key) do
    case Map.get(map, key, %{}) do
      value when is_map(value) -> {:ok, value}
      _value -> invalid_condition("Thompson Sampling #{key} config must be a map")
    end
  end

  defp reject_condition_priors(priors) do
    case Map.get(priors, "conditions", %{}) do
      conditions when conditions == %{} -> :ok
      _conditions -> invalid_condition("Thompson Sampling per-condition priors are not supported")
    end
  end

  defp validate_thompson_priors(policy_config) do
    prior = policy_config["priors"]["default"]

    with :ok <- validate_positive_prior(prior, "alpha"),
         :ok <- validate_positive_prior(prior, "beta") do
      :ok
    end
  end

  defp validate_positive_prior(prior, key) do
    case Map.get(prior, key) do
      value when is_number(value) and value >= 0.0001 and value <= 1_000.0 ->
        :ok

      _value ->
        invalid_condition("Thompson Sampling prior #{key} must be between 0.0001 and 1000")
    end
  end

  defp validate_thompson_guardrails(policy_config) do
    guardrails = policy_config["guardrails"]

    cond do
      not non_negative_integer?(guardrails["warm_up_assignments"]) ->
        invalid_condition("Thompson Sampling warm-up assignments must be a non-negative integer")

      not share?(guardrails["max_condition_share"]) ->
        invalid_condition(
          "Thompson Sampling max condition share must be greater than 0 and at most 1"
        )

      not is_nil(guardrails["fixed_control_allocation"]) and
          not share?(guardrails["fixed_control_allocation"]) ->
        invalid_condition(
          "Thompson Sampling fixed control allocation must be greater than 0 and at most 1"
        )

      not share?(guardrails["imbalance_threshold"]) ->
        invalid_condition(
          "Thompson Sampling imbalance threshold must be greater than 0 and at most 1"
        )

      true ->
        :ok
    end
  end

  defp non_negative_integer?(value), do: is_integer(value) and value >= 0
  defp share?(value), do: is_number(value) and value > 0.0 and value <= 1.0

  defp invalid_condition(message) do
    {:error, %ExperimentError{type: :invalid_condition, message: message}}
  end
end
