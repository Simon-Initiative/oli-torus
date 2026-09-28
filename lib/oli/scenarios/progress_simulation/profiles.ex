defmodule Oli.Scenarios.ProgressSimulation.Profiles do
  @moduledoc """
  Fixed synthetic learner presets used by course progress simulation.

  The public behavior contract is intentionally small. Timing distributions are fixed
  alongside each preset and can't be overridden by individual scenarios.
  """

  @names ~w(high_proficiency steady_learner persistent_learner low_engagement)

  @profiles %{
    "high_proficiency" => %{
      course_reach: {0.90, 1.0},
      activity_participation: {0.90, 1.0},
      initial_correctness: {0.85, 0.95},
      practice_attempts: 2,
      assessment_attempts: 2,
      improvement_per_attempt: 0.04
    },
    "steady_learner" => %{
      course_reach: {0.80, 1.0},
      activity_participation: {0.75, 0.95},
      initial_correctness: {0.60, 0.80},
      practice_attempts: 2,
      assessment_attempts: 2,
      improvement_per_attempt: 0.10
    },
    "persistent_learner" => %{
      course_reach: {0.90, 1.0},
      activity_participation: {0.90, 1.0},
      initial_correctness: {0.30, 0.55},
      practice_attempts: 4,
      assessment_attempts: 3,
      improvement_per_attempt: 0.18
    },
    "low_engagement" => %{
      course_reach: {0.15, 0.55},
      activity_participation: {0.25, 0.60},
      initial_correctness: {0.45, 0.70},
      practice_attempts: 1,
      assessment_attempts: 1,
      improvement_per_attempt: 0.05
    }
  }

  @timings %{
    "high_proficiency" => %{
      start_delay: {0, 120_000, 600_000},
      page_time: {600_000, 780_000, 1_800_000},
      answer_time: {15_000, 30_000, 90_000},
      retry_delay: {60_000, 75_000, 150_000},
      break_probability: 0.05,
      break_duration: {300_000, 600_000, 1_800_000},
      session_pages: {3, 6},
      session_gap: {14_400_000, 28_800_000, 57_600_000}
    },
    "steady_learner" => %{
      start_delay: {0, 300_000, 1_800_000},
      page_time: {600_000, 1_080_000, 2_400_000},
      answer_time: {15_000, 45_000, 120_000},
      retry_delay: {60_000, 90_000, 180_000},
      break_probability: 0.15,
      break_duration: {300_000, 900_000, 2_700_000},
      session_pages: {2, 4},
      session_gap: {14_400_000, 43_200_000, 86_400_000}
    },
    "persistent_learner" => %{
      start_delay: {0, 300_000, 1_800_000},
      page_time: {600_000, 1_500_000, 3_600_000},
      answer_time: {30_000, 75_000, 180_000},
      retry_delay: {60_000, 120_000, 300_000},
      break_probability: 0.10,
      break_duration: {300_000, 900_000, 2_700_000},
      session_pages: {2, 5},
      session_gap: {7_200_000, 28_800_000, 57_600_000}
    },
    "low_engagement" => %{
      start_delay: {0, 1_800_000, 10_800_000},
      page_time: {600_000, 900_000, 2_400_000},
      answer_time: {15_000, 35_000, 120_000},
      retry_delay: {60_000, 120_000, 300_000},
      break_probability: 0.35,
      break_duration: {600_000, 1_800_000, 7_200_000},
      session_pages: {1, 2},
      session_gap: {43_200_000, 86_400_000, 172_800_000}
    }
  }

  @doc "Returns the stable names of all built-in profiles."
  def names, do: @names

  @doc "Resolves a named immutable behavior preset."
  def resolve(name) do
    case Map.fetch(@profiles, name) do
      {:ok, profile} -> {:ok, Map.put(profile, :name, name)}
      :error -> {:error, "unknown profile '#{name}'"}
    end
  end

  @doc "Returns the fixed timing distributions for a profile."
  def timing(name), do: Map.fetch!(@timings, name)

  @doc """
  Validates and normalizes top-level timing mode configuration.

  Defaults to fast mode for `nil`. Timing maps must contain only `mode`, using
  string keys and values or atom keys and values; additional keys are rejected.
  """
  def normalize_mode(nil), do: {:ok, :fast}
  def normalize_mode(%{"mode" => "fast"} = timing) when map_size(timing) == 1, do: {:ok, :fast}
  def normalize_mode(%{"mode" => "paced"} = timing) when map_size(timing) == 1, do: {:ok, :paced}
  def normalize_mode(%{mode: :fast} = timing) when map_size(timing) == 1, do: {:ok, :fast}
  def normalize_mode(%{mode: :paced} = timing) when map_size(timing) == 1, do: {:ok, :paced}

  def normalize_mode(_),
    do: {:error, "simulate_progress.timing must contain only mode: fast or mode: paced"}
end
