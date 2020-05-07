defmodule Oli.Activities.Model.Response do

  defstruct [:id, :match, :score, :feedback]

  def parse(%{"id" => id, "match" => match, "score" => score, "feedback" => feedback }) do

    case Oli.Activities.Model.Feedback.parse(feedback) do
      {:ok, feedback} -> {:ok, %Oli.Activities.Model.Response{
        id: id,
        match: match,
        score: score,
        feedback: feedback
      }}
      error -> error
    end

  end

  def parse(responses) when is_list(responses) do
    Enum.map(responses, &parse/1)
    |> Oli.Activities.ParseUtils.items_or_errors()
  end

  def parse(_) do
    {:error, "invalid response"}
  end

end
