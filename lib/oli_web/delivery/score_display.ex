defmodule OliWeb.Delivery.ScoreDisplay do
  @moduledoc """
  Shared score display helpers for threshold-based score status.
  """

  @default_threshold_pct 40.0

  @spec default_threshold_pct() :: float()
  def default_threshold_pct, do: @default_threshold_pct

  @spec score_status(number() | nil, number() | nil, number()) :: :good | :bad | :none
  def score_status(score, out_of, threshold_pct \\ @default_threshold_pct)

  def score_status(nil, _out_of, _threshold_pct), do: :none
  def score_status(_score, out_of, _threshold_pct) when out_of in [nil, 0, +0.0, -0.0], do: :none

  def score_status(score, out_of, threshold_pct) do
    score
    |> percentage(out_of)
    |> score_status_from_percentage(threshold_pct)
  end

  @spec score_status_from_percentage(number() | nil, number()) :: :good | :bad | :none
  def score_status_from_percentage(percentage, threshold_pct \\ @default_threshold_pct)

  def score_status_from_percentage(nil, _threshold_pct), do: :none

  def score_status_from_percentage(percentage, threshold_pct) when percentage < threshold_pct,
    do: :bad

  def score_status_from_percentage(_percentage, _threshold_pct), do: :good

  @spec percentage(number() | nil, number() | nil) :: float() | nil
  def percentage(nil, _out_of), do: nil
  def percentage(_score, out_of) when out_of in [nil, 0, +0.0, -0.0], do: nil
  def percentage(score, out_of), do: score / out_of * 100
end
