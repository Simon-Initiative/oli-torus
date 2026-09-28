defmodule Oli.Scenarios.ProgressSimulation.Policy do
  @moduledoc "Pure deterministic decisions for profile-driven learner simulation."

  @doc "Samples fixed traits for one learner."
  def learner_traits(profile, seed, learner_identity) do
    %{
      correctness: range(profile.initial_correctness, seed, learner_identity, :correctness),
      course_reach: range(profile.course_reach, seed, learner_identity, :course_reach),
      pace_tendency: sample({seed, learner_identity, :pace_tendency}),
      participation: range(profile.activity_participation, seed, learner_identity, :participation)
    }
  end

  @doc "Returns whether an independently keyed opportunity is taken."
  def take?(probability, seed, learner_identity, key),
    do: sample({seed, learner_identity, key}) < probability

  @doc "Returns the correctness probability for a numbered attempt."
  def correctness(traits, profile, attempt_number) do
    min(traits.correctness + (attempt_number - 1) * profile.improvement_per_attempt, 0.98)
  end

  @doc "Returns the bounded prefix length visited for sampled course reach."
  def pages_to_visit(total_pages, reach), do: min(ceil(total_pages * reach), total_pages)

  @doc "Samples a triangular duration in milliseconds."
  def triangular({minimum, typical, maximum}, key) do
    unit = sample({key, :triangular})
    spread = maximum - minimum

    case spread do
      0 -> minimum
      _ -> round(triangular_value(unit, minimum, typical, maximum, spread))
    end
  end

  @doc "Samples a duration adjusted by a stable learner pace tendency."
  def paced_triangular({minimum, typical, maximum}, tendency, key) do
    adjustment = round((tendency - 0.5) * (maximum - minimum) * 0.5)
    adjusted_typical = (typical + adjustment) |> max(minimum) |> min(maximum)
    triangular({minimum, adjusted_typical, maximum}, key)
  end

  @doc "Samples the inclusive page capacity for one modeled study session."
  def session_page_limit({minimum, maximum}, seed, identity, ordinal) do
    minimum + trunc(sample({seed, identity, :session_pages, ordinal}) * (maximum - minimum + 1))
  end

  @doc "Returns a stable pseudo-random sample in `[0, 1)`."
  def sample(key), do: :erlang.phash2(key, 1_000_000) / 1_000_000

  defp range({minimum, maximum}, seed, identity, key),
    do: minimum + sample({seed, identity, key}) * (maximum - minimum)

  defp triangular_value(unit, minimum, typical, maximum, spread) do
    split = (typical - minimum) / spread

    case unit < split do
      true -> minimum + :math.sqrt(unit * spread * (typical - minimum))
      false -> maximum - :math.sqrt((1 - unit) * spread * (maximum - typical))
    end
  end
end
