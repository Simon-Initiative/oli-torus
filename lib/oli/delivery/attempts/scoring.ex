defmodule Oli.Delivery.Attempts.Scoring do

  alias Oli.Delivery.Attempts.Result
  alias Oli.Resources.ScoringStrategy

  @doc """
  Calculates a result from a list of maps that contain a score and out_of.

  Returns a `%Result{}` struct with the calculated score.
  """
  def calculate_score(strategy_id, items) when is_number(strategy_id) do
    calculate_score(ScoringStrategy.get_type_by_id(strategy_id), items)
  end

  def calculate_score("average", items) do
    # the average calculated is normalized, but then
    # reported back as a score out of the maximum possible of
    # any attempt.
    {total, max_out_of} = Enum.reduce(items, {0, 0}, fn p, {total, max_out_of} ->
      {total + (p.score / p.out_of), if max_out_of < p.out_of do p.out_of else max_out_of end}
    end)

    %Result{
      score: total / length(items) * max_out_of,
      out_of: max_out_of
    }
  end

  def calculate_score("best", items) do
    {score, out_of, _} = Enum.reduce(items, {0, 0, 0.0}, fn p, {score, out_of, best} ->
      if p.score / p.out_of > best do
        {p.score, p.out_of, p.score / p.out_of}
      else
        {score, out_of, best}
      end
    end)

    %Result{
      score: score,
      out_of: out_of
    }
  end

  def calculate_score("most_recent", items) do
    most_recent = Enum.reverse(items) |> hd

    %Result{
      score: Map.get(most_recent, :score),
      out_of: Map.get(most_recent, :out_of)
    }
  end

  def calculate_score("total", items) do
    {score, out_of} = Enum.reduce(items, {0, 0}, fn p, {score, out_of} ->
      {score + p.score, out_of + p.out_of}
    end)
    %Result{
      score: score,
      out_of: out_of
    }
  end

end
