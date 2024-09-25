defmodule Oli.Delivery.Attempts.Scoring do
  alias Oli.Delivery.Evaluation.Result
  alias Oli.Resources.ScoringStrategy

  @doc """
  Calculates a result from a list of maps that contain a score and out_of.

  This can be used either by passing in the strategy id or directly passing
  in the scoring strategy string id.

  A key aspect of the implmementations here is that they are correct in the
  face of attempts that might have different `out_of` values. This situation
  can occur when attempts are simply pinned to different revisions of a resource
  that have a different number of activities.

  Returns a `%Result{}` struct with the calculated score.
  """

  def calculate_score(strategy_id, items) when is_number(strategy_id) do
    calculate_score(ScoringStrategy.get_type_by_id(strategy_id), translate_nils(items))
  end

  # The average calculated here is normalized out of 100%, but then
  # reported back as a score out of the maximum possible of
  # any attempt. So an average of two attempts with 5/10 on one and 10/20 on
  # another would result in a 10/20 result. This approach allows the
  # correct handling of cases where attempts are pinned to different revisions
  # of a resource with a possibly different number of activities
  def calculate_score("average", items) do
    {total, max_out_of} =
      Enum.reduce(items, {0, 0}, fn p, {total, max_out_of} ->
        {total + safe_percentage(p.score, p.out_of),
         if max_out_of < p.out_of do
           p.out_of
         else
           max_out_of
         end}
      end)

    %Result{
      score: total / length(items) * max_out_of,
      out_of: max_out_of
    }
  end

  # The 'best' score is the attempt with the highest percentage correct,
  # not the highest raw score.
  def calculate_score("best", items) do
    {score, out_of, _} =
      Enum.reduce(items, {0, 0, 0.0}, fn p, {score, out_of, best} ->
        if safe_percentage(p.score, p.out_of) >= best do
          {p.score, p.out_of, safe_percentage(p.score, p.out_of)}
        else
          {score, out_of, best}
        end
      end)

    %Result{
      score: score,
      out_of: out_of
    }
  end

  # The most recent is assumed to be the last item in the list
  def calculate_score("most_recent", items) do

    # Sort the resource_attemmpts by the date_evaluated field, so that
    # the most recent evaluated attempt is the first item in the list.
    #
    # This makes this scoring strategy a little more robust in the face of
    # attempts where somehow the most recent attempt does not match
    # the natural database order - or somehow the query doesn't return
    # in database order.
    [most_recent | _] = Enum.sort_by(items, & &1.date_evaluated, &>=/2)

    %Result{
      score: Map.get(most_recent, :score),
      out_of: Map.get(most_recent, :out_of)
    }
  end

  # The total strategy simply adds up the scores and adds up the out_of
  def calculate_score("total", items) do
    {score, out_of} =
      Enum.reduce(items, {0, 0}, fn p, {score, out_of} ->
        {score + p.score, out_of + p.out_of}
      end)

    %Result{
      score: score,
      out_of: out_of
    }
  end

  # Instead of failing at runtime if there is ever a strategy passed in that
  # we do not handle, we default to the "average" strategy.
  def calculate_score(_, items) do
    calculate_score("average", items)
  end

  defp translate_nils(items) do
    Enum.map(items, fn p ->
      %{
        score:
          if is_nil(p.score) do
            0
          else
            p.score
          end,
        out_of:
          if is_nil(p.out_of) do
            0
          else
            p.out_of
          end
      }
    end)
  end

  defp safe_percentage(score, out_of) do
    case out_of do
      nil -> 0.0
      0.0 -> 0.0
      0 -> 0.0
      _ -> score / out_of
    end
  end
end
