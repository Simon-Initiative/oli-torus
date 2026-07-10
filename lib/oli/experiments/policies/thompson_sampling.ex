defmodule Oli.Experiments.Policies.ThompsonSampling do
  @moduledoc """
  Thompson Sampling contract support for binary rewards.
  """

  @behaviour Oli.Experiments.Policies.Policy

  alias Oli.Experiments.Policies.{PolicyAssignment, PolicyUpdate}

  @version "thompson_sampling:v2"
  @default_prior_alpha 1.0
  @default_prior_beta 1.0
  @min_prior 0.0001
  @max_prior 1_000.0

  def version, do: @version

  def default_policy_config do
    %{
      "reward_source" => "activity_attempt:full_credit",
      "priors" => %{
        "default" => %{"alpha" => @default_prior_alpha, "beta" => @default_prior_beta},
        "conditions" => %{}
      },
      "guardrails" => %{
        "manual_pause_enabled" => true,
        "warm_up_assignments" => 0,
        "max_condition_share" => 1.0,
        "fixed_control_allocation" => nil,
        "imbalance_threshold" => 1.0
      }
    }
  end

  def initial_state(policy_config, conditions) when is_list(conditions) do
    Enum.reduce_while(conditions, {:ok, %{}}, fn condition, {:ok, state} ->
      condition_code = condition.condition_code

      case normalize_condition_state(policy_config || %{}, %{}, condition_code) do
        {:ok, condition_state} -> {:cont, {:ok, Map.put(state, condition_code, condition_state)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @impl true
  def assign(policy_config, policy_state, %{conditions: conditions} = context) do
    case conditions do
      [] ->
        {:error, :no_conditions}

      _ ->
        with {:ok, {condition, sample}} <-
               select_condition(policy_config || %{}, policy_state || %{}, conditions, context) do
          {:ok,
           %PolicyAssignment{
             condition_id: condition.id,
             condition_code: condition.condition_code,
             policy_version: @version,
             metadata: %{posterior_sample: sample}
           }}
        end
    end
  end

  @impl true
  def record_reward(policy_config, policy_state, %{
        condition_code: condition_code,
        reward_value: reward_value
      }) do
    previous_state = policy_state || %{}

    with {:ok, condition_state} <-
           normalize_condition_state(policy_config || %{}, previous_state, condition_code),
         {:ok, reward_success?} <- binary_reward_success?(reward_value) do
      {successes, failures} =
        case reward_success? do
          true -> {condition_state["successes"] + 1, condition_state["failures"]}
          false -> {condition_state["successes"], condition_state["failures"] + 1}
        end

      next_condition_state =
        condition_state
        |> Map.put("successes", successes)
        |> Map.put("failures", failures)
        |> Map.put("posterior_alpha", condition_state["prior_alpha"] + successes)
        |> Map.put("posterior_beta", condition_state["prior_beta"] + failures)

      next_state = Map.put(previous_state, condition_code, next_condition_state)

      {:ok,
       %PolicyUpdate{
         algorithm_version: @version,
         previous_state: previous_state,
         next_state: next_state,
         update_reason: "binary_reward",
         counters: %{
           reward_success_count: success_counter(reward_success?),
           reward_failure_count: failure_counter(reward_success?)
         }
       }}
    end
  end

  defp select_condition(policy_config, policy_state, conditions, context) do
    Enum.reduce_while(conditions, {:ok, nil}, fn condition, {:ok, selected} ->
      condition_code = condition.condition_code

      with {:ok, condition_state} <-
             normalize_condition_state(policy_config, policy_state, condition_code),
           {:ok, sample} <- sample_posterior(context, condition_code, condition_state) do
        {:cont, {:ok, max_sampled_condition(selected, {condition, sample})}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp normalize_condition_state(policy_config, policy_state, condition_code) do
    condition_state = Map.get(policy_state, condition_code, %{})

    with {:ok, {prior_alpha, prior_beta}} <-
           normalize_priors(policy_config, condition_state, condition_code),
         {:ok, successes} <- non_negative_integer(condition_state, "successes", 0),
         {:ok, failures} <- non_negative_integer(condition_state, "failures", 0) do
      {:ok,
       %{
         "prior_alpha" => prior_alpha,
         "prior_beta" => prior_beta,
         "successes" => successes,
         "failures" => failures,
         "posterior_alpha" => prior_alpha + successes,
         "posterior_beta" => prior_beta + failures
       }}
    end
  end

  defp normalize_priors(policy_config, condition_state, condition_code) do
    with {:ok, {default_alpha, default_beta}} <- default_priors(policy_config),
         {:ok, {configured_alpha, configured_beta}} <-
           configured_condition_priors(policy_config, condition_code, default_alpha, default_beta),
         {:ok, prior_alpha} <-
           positive_number(condition_state, "prior_alpha", configured_alpha),
         {:ok, prior_beta} <- positive_number(condition_state, "prior_beta", configured_beta) do
      {:ok, {prior_alpha, prior_beta}}
    end
  end

  defp default_priors(policy_config) do
    default_config =
      policy_config
      |> Map.get("priors", %{})
      |> Map.get("default", %{})

    with {:ok, alpha} <- positive_number(default_config, "alpha", @default_prior_alpha),
         {:ok, beta} <- positive_number(default_config, "beta", @default_prior_beta) do
      {:ok, {alpha, beta}}
    end
  end

  defp configured_condition_priors(policy_config, condition_code, default_alpha, default_beta) do
    condition_config =
      policy_config
      |> Map.get("priors", %{})
      |> Map.get("conditions", %{})
      |> Map.get(condition_code, %{})

    with {:ok, alpha} <- positive_number(condition_config, "alpha", default_alpha),
         {:ok, beta} <- positive_number(condition_config, "beta", default_beta) do
      {:ok, {alpha, beta}}
    end
  end

  defp positive_number(map, key, default) do
    map
    |> Map.get(key, default)
    |> number_value()
    |> case do
      {:ok, value} when value >= @min_prior and value <= @max_prior -> {:ok, value}
      {:ok, _value} -> {:error, {:invalid_prior, key}}
      :error -> {:error, {:invalid_prior, key}}
    end
  end

  defp non_negative_integer(map, key, default) do
    case Map.get(map, key, default) do
      value when is_integer(value) and value >= 0 -> {:ok, value}
      _value -> {:error, {:invalid_observed_count, key}}
    end
  end

  defp number_value(value) when is_integer(value), do: {:ok, value * 1.0}

  defp number_value(value) when is_float(value) do
    case finite?(value) do
      true -> {:ok, value}
      false -> :error
    end
  end

  defp number_value(_value), do: :error

  defp binary_reward_success?(reward_value) when is_integer(reward_value),
    do: binary_reward_success?(reward_value * 1.0)

  defp binary_reward_success?(reward_value) when is_float(reward_value) do
    cond do
      not finite?(reward_value) -> {:error, :invalid_reward_value}
      reward_value == 0.0 -> {:ok, false}
      reward_value == 1.0 -> {:ok, true}
      true -> {:error, :invalid_reward_value}
    end
  end

  defp binary_reward_success?(_reward_value), do: {:error, :invalid_reward_value}

  defp finite?(value), do: value == value and value not in [:infinity, :neg_infinity]

  defp max_sampled_condition(nil, sampled_condition), do: sampled_condition

  defp max_sampled_condition(
         {_selected_condition, selected_sample} = selected,
         {_condition, sample}
       )
       when selected_sample >= sample,
       do: selected

  defp max_sampled_condition(_selected, sampled_condition), do: sampled_condition

  defp sample_posterior(%{beta_sampler: sampler}, condition_code, condition_state)
       when is_function(sampler, 3) do
    sampler.(
      condition_state["posterior_alpha"],
      condition_state["posterior_beta"],
      condition_code
    )
    |> sample_result()
  end

  defp sample_posterior(%{"beta_sampler" => sampler}, condition_code, condition_state)
       when is_function(sampler, 3) do
    sampler.(
      condition_state["posterior_alpha"],
      condition_state["posterior_beta"],
      condition_code
    )
    |> sample_result()
  end

  defp sample_posterior(%{posterior_samples: samples}, condition_code, _condition_state)
       when is_map(samples) do
    samples
    |> Map.fetch(condition_code)
    |> case do
      {:ok, sample} -> sample_result(sample)
      :error -> {:error, {:missing_posterior_sample, condition_code}}
    end
  end

  defp sample_posterior(%{"posterior_samples" => samples}, condition_code, _condition_state)
       when is_map(samples) do
    samples
    |> Map.fetch(condition_code)
    |> case do
      {:ok, sample} -> sample_result(sample)
      :error -> {:error, {:missing_posterior_sample, condition_code}}
    end
  end

  defp sample_posterior(_context, _condition_code, condition_state) do
    sample_beta(condition_state["posterior_alpha"], condition_state["posterior_beta"])
    |> sample_result()
  end

  defp sample_result({:ok, sample}), do: sample_result(sample)

  defp sample_result(sample) when is_number(sample) and sample >= 0.0 and sample <= 1.0,
    do: {:ok, sample * 1.0}

  defp sample_result(_sample), do: {:error, :invalid_posterior_sample}

  defp sample_beta(alpha, beta) do
    alpha_sample = sample_gamma(alpha)
    beta_sample = sample_gamma(beta)

    alpha_sample / (alpha_sample + beta_sample)
  end

  defp sample_gamma(shape) when shape < 1.0 do
    sample_gamma(shape + 1.0) * :math.pow(:rand.uniform(), 1.0 / shape)
  end

  defp sample_gamma(shape) do
    d = shape - 1.0 / 3.0
    c = 1.0 / :math.sqrt(9.0 * d)

    gamma_candidate(d, c)
  end

  defp gamma_candidate(d, c) do
    x = normal_sample()
    v = :math.pow(1.0 + c * x, 3)

    case v > 0.0 do
      false ->
        gamma_candidate(d, c)

      true ->
        u = :rand.uniform()
        x_squared = x * x

        cond do
          u < 1.0 - 0.0331 * x_squared * x_squared ->
            d * v

          :math.log(u) < x_squared / 2.0 + d * (1.0 - v + :math.log(v)) ->
            d * v

          true ->
            gamma_candidate(d, c)
        end
    end
  end

  defp normal_sample do
    u1 = :rand.uniform()
    u2 = :rand.uniform()

    :math.sqrt(-2.0 * :math.log(u1)) * :math.cos(2.0 * :math.pi() * u2)
  end

  defp success_counter(true), do: 1
  defp success_counter(false), do: 0

  defp failure_counter(true), do: 0
  defp failure_counter(false), do: 1
end
