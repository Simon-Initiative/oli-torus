defmodule Oli.Delivery.Evaluation.Regex do

  alias Oli.Delivery.Attempts.{StudentInput, Result}
  alias Oli.Activities.Model.{Part, Response}

  @behaviour Oli.Delivery.Evaluation.Evaluator

  def evaluate(%Part{} = part, %StudentInput{input: input}) do

    case Enum.reduce(part.responses, {input, nil, -1, -1}, &consider_response/2) do
      {_, %Response{feedback: feedback, score: score}, _, out_of} -> {:ok, {feedback, %Result{score: score, out_of: out_of}}}
      {_, nil, _, _} -> {:error, "no matching response found"}
    end

  end

  # Consider one response
  defp consider_response(%Response{score: score, match: match} = current, {input, best_response, best_score, out_of}) do

    # Track the highest point value out of all responses
    out_of = case score > out_of do
      true -> score
      false -> out_of
    end

    # Determine if this response should replace the `best_response`
    case {match, input, best_score < score} do

      # We have an exact match on input and match and this score is
      # higher than the best score
      {same, same, true} -> {input, current, score, out_of}

      # We hit the * case and it yields a point value higher than
      # the current best
      {"*", _, true} -> {input, current, score, out_of}

      # Did not match or wasn't higher than best
      _ -> {input, best_response, best_score, out_of}
    end

  end

end
