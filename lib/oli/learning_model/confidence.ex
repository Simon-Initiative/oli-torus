defmodule Oli.LearningModel.Confidence do
  @moduledoc "Derives confidence from unique activity-part evidence using the configured Hill curve."

  alias Oli.LearningModel.Config

  @doc """
  Calculates `n^steepness / (n^steepness + midpoint^steepness)` for a unique-part count.
  Callers can supply one configuration snapshot for an entire batch of estimates.
  """
  @spec calculate(non_neg_integer(), Config.t()) :: float()
  def calculate(n, config \\ Config.fetch!())

  def calculate(n, %Config{confidence_midpoint: midpoint, confidence_steepness: steepness})
      when is_integer(n) and n >= 0 do
    # Keep the base at most one to avoid overflowing powers for large counts or steepness.
    case n <= midpoint do
      true ->
        ratio = :math.pow(n / midpoint, steepness)
        ratio / (1.0 + ratio)

      false ->
        1.0 / (1.0 + :math.pow(midpoint / n, steepness))
    end
  end
end
