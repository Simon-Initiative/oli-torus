defmodule Oli.LearningModel.LktAoa.Transition do
  @moduledoc """
  Pure LKT-AOA transition logic.

  Each opportunity updates practice count and recency with the observed binary
  outcome first. The model then predicts from that updated state and folds the
  prediction into AOA, so the current response affects proficiency immediately.
  """

  alias Oli.LearningModel.Config
  alias Oli.LearningModel.LearningState
  alias Oli.LearningModel.LktAoa.Contribution

  @type state_key :: Contribution.state_key()

  @doc "Predicts correctness using the supplied practice count, recency, and coefficients."
  @spec probability(LearningState.t(), %{beta_lo: float(), beta_part: float()}, Config.t()) ::
          float()
  def probability(%LearningState{} = state, contribution, %Config{} = config) do
    logit =
      contribution.beta_lo +
        contribution.beta_part +
        config.gamma * :math.log(state.attempt_count + 1) +
        config.rho * state.recency_logit

    logistic(logit)
  end

  @doc "Applies the response, then averages the prediction from the updated learner state."
  @spec apply_proficiency(
          LearningState.t(),
          %{beta_lo: float(), beta_part: float(), correct: 0 | 1},
          Config.t()
        ) :: LearningState.t()
  def apply_proficiency(%LearningState{} = state, contribution, %Config{} = config) do
    correct = contribution.correct
    new_success_score = config.recency_decay * state.success_score + correct
    new_failure_score = config.recency_decay * state.failure_score + (1 - correct)

    updated_state = %{
      state
      | attempt_count: state.attempt_count + 1,
        success_score: new_success_score,
        failure_score: new_failure_score,
        recency_logit: :math.log((new_success_score + 1) / (new_failure_score + 1))
    }

    p_correct = probability(updated_state, contribution, config)

    # This running-average form avoids multiplying a large historical count by
    # AOA while preserving the same all-opportunities average.
    %{updated_state | aoa: state.aoa + (p_correct - state.aoa) / updated_state.attempt_count}
  end

  @doc "Increments the persisted unique-part count; confidence is derived when reading estimates."
  @spec apply_evidence_count(LearningState.t(), non_neg_integer()) :: LearningState.t()
  def apply_evidence_count(%LearningState{} = state, increment)
      when is_integer(increment) and increment >= 0 do
    %{state | unique_activity_part_count: state.unique_activity_part_count + increment}
  end

  @spec replay_by_state(
          %{state_key() => LearningState.t()},
          [map()],
          Config.t()
        ) :: {:ok, %{state_key() => LearningState.t()}} | {:error, term()}
  def replay_by_state(states, contributions, %Config{} = config),
    do: replay_by_state(states, contributions, %{}, config)

  @spec replay_by_state(
          %{state_key() => LearningState.t()},
          [map()],
          %{state_key() => non_neg_integer()},
          Config.t()
        ) :: {:ok, %{state_key() => LearningState.t()}} | {:error, term()}
  def replay_by_state(states, contributions, confidence_increments, %Config{} = config)
      when is_map(states) and is_list(contributions) and is_map(confidence_increments) do
    with :ok <- validate_evaluation_dates(contributions) do
      contributions
      |> Enum.group_by(& &1.state_key)
      |> Enum.reduce_while({:ok, states}, fn {state_key, grouped}, {:ok, states} ->
        case Map.fetch(states, state_key) do
          {:ok, state} ->
            final_state =
              grouped
              |> sort_contributions()
              |> Enum.reduce(state, fn contribution, state ->
                apply_proficiency(state, contribution, config)
              end)
              |> apply_evidence_count(Map.get(confidence_increments, state_key, 0))

            {:cont, {:ok, Map.put(states, state_key, final_state)}}

          :error ->
            {:halt, {:error, {:missing_learning_state, state_key}}}
        end
      end)
    end
  end

  @spec sort_contributions([map()]) :: [map()]
  def sort_contributions(contributions) do
    Enum.sort_by(contributions, fn contribution ->
      {DateTime.to_unix(contribution.date_evaluated, :microsecond),
       contribution.part_attempt_guid}
    end)
  end

  @spec validate_evaluation_dates([map()]) :: :ok | {:error, term()}
  def validate_evaluation_dates(contributions) do
    Enum.find(contributions, fn contribution -> is_nil(contribution.date_evaluated) end)
    |> case do
      nil -> :ok
      contribution -> {:error, {:missing_date_evaluated, contribution.part_attempt_guid}}
    end
  end

  # Numerically stable logistic avoids overflow for extreme logits while retaining
  # the ordinary 1 / (1 + exp(-x)) result around zero.
  defp logistic(logit) when logit >= 0 do
    z = :math.exp(-logit)
    1 / (1 + z)
  end

  defp logistic(logit) do
    z = :math.exp(logit)
    z / (1 + z)
  end
end
