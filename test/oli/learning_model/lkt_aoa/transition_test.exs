defmodule Oli.LearningModel.LktAoa.TransitionTest do
  use ExUnit.Case, async: true

  alias Oli.LearningModel.Config
  alias Oli.LearningModel.LearningState
  alias Oli.LearningModel.LktAoa.Transition

  @config %Config{gamma: 0.1, rho: 1.0, recency_decay: 0.9, confidence_saturation: 3.0}
  @base_time ~U[2026-08-24 12:00:00Z]

  test "first opportunity predicts from neutral state before applying the observed outcome" do
    state = neutral_state()

    result =
      Transition.apply_proficiency(
        state,
        %{beta_lo: 0.2, beta_part: -0.4, correct: 1},
        @config
      )

    p_correct = logistic(-0.2)

    assert_close(result.aoa, p_correct)
    assert result.attempt_count == 1
    assert_close(result.success_score, 1.0)
    assert_close(result.failure_score, 0.0)
    assert_close(result.recency_logit, :math.log(2.0))
  end

  test "subsequent opportunity uses stable running AOA before recency changes" do
    state = %LearningState{
      attempt_count: 3,
      aoa: 0.6,
      success_score: 2.0,
      failure_score: 1.0,
      recency_logit: :math.log(3.0 / 2.0),
      unique_activity_part_count: 0,
      confidence: 0.0
    }

    result =
      Transition.apply_proficiency(
        state,
        %{beta_lo: 0.25, beta_part: 0.5, correct: 0},
        @config
      )

    p_correct =
      logistic(0.25 + 0.5 + @config.gamma * :math.log(4) + @config.rho * state.recency_logit)

    assert result.attempt_count == 4
    assert_close(result.aoa, state.aoa + (p_correct - state.aoa) / 4)
    assert_close(result.success_score, 1.8)
    assert_close(result.failure_score, 1.9)
    assert_close(result.recency_logit, :math.log(2.8 / 2.9))
  end

  test "probability remains stable for extreme logits" do
    high =
      Transition.probability(
        %LearningState{neutral_state() | recency_logit: 1_000.0},
        %{beta_lo: 1_000.0, beta_part: 1_000.0},
        @config
      )

    low =
      Transition.probability(
        %LearningState{neutral_state() | recency_logit: -1_000.0},
        %{beta_lo: -1_000.0, beta_part: -1_000.0},
        @config
      )

    assert high == 1.0
    assert low == 0.0
  end

  test "confidence uses unique part count and saturation constant" do
    result = Transition.apply_confidence(neutral_state(), 2, @config)

    assert result.unique_activity_part_count == 2
    assert_close(result.confidence, 1.0 - :math.exp(-2 / 3.0))
  end

  test "replay sorts each state by date_evaluated and guid tie breaker" do
    key = {1, 2, 3}

    late = contribution(key, "b-guid", DateTime.add(@base_time, 60, :second), 1)
    early = contribution(key, "z-guid", @base_time, 0)
    tied = contribution(key, "a-guid", DateTime.add(@base_time, 60, :second), 0)

    assert {:ok, %{^key => final}} =
             Transition.replay_by_state(
               %{key => neutral_state()},
               [late, early, tied],
               %{},
               @config
             )

    manual =
      neutral_state()
      |> Transition.apply_proficiency(Map.take(early, [:beta_lo, :beta_part, :correct]), @config)
      |> Transition.apply_proficiency(Map.take(tied, [:beta_lo, :beta_part, :correct]), @config)
      |> Transition.apply_proficiency(Map.take(late, [:beta_lo, :beta_part, :correct]), @config)

    assert final.attempt_count == 3
    assert_close(final.aoa, manual.aoa)
    assert_close(final.recency_logit, manual.recency_logit)
  end

  test "replay applies confidence increments independently per state" do
    first_key = {1, 2, 3}
    second_key = {1, 2, 4}

    contributions = [
      contribution(first_key, "a", @base_time, 1),
      contribution(second_key, "b", @base_time, 0)
    ]

    assert {:ok, result} =
             Transition.replay_by_state(
               %{first_key => neutral_state(), second_key => neutral_state()},
               contributions,
               %{first_key => 2, second_key => 1},
               @config
             )

    assert result[first_key].attempt_count == 1
    assert result[second_key].attempt_count == 1
    assert result[first_key].unique_activity_part_count == 2
    assert result[second_key].unique_activity_part_count == 1
  end

  test "replay rejects null evaluation dates before applying transitions" do
    key = {1, 2, 3}

    assert Transition.replay_by_state(
             %{key => neutral_state()},
             [contribution(key, "missing-date", nil, 1)],
             %{},
             @config
           ) == {:error, {:missing_date_evaluated, "missing-date"}}
  end

  test "replay reports missing state keys" do
    key = {1, 2, 3}

    assert Transition.replay_by_state(%{}, [contribution(key, "a", @base_time, 1)], %{}, @config) ==
             {:error, {:missing_learning_state, key}}
  end

  defp neutral_state do
    %LearningState{
      attempt_count: 0,
      success_score: 0.0,
      failure_score: 0.0,
      recency_logit: 0.0,
      aoa: 0.0,
      unique_activity_part_count: 0,
      confidence: 0.0
    }
  end

  defp contribution(state_key, guid, date_evaluated, correct) do
    %{
      state_key: state_key,
      part_attempt_guid: guid,
      date_evaluated: date_evaluated,
      beta_lo: 0.0,
      beta_part: 0.0,
      correct: correct
    }
  end

  defp logistic(value), do: 1 / (1 + :math.exp(-value))

  defp assert_close(actual, expected), do: assert_in_delta(actual, expected, 1.0e-12)
end
