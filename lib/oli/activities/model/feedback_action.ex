defmodule Oli.Activities.Model.FeedbackAction do
  defstruct [:id, :score, :feedback]

  def parse(%{"id" => id, "score" => score, "feedback" => feedback}) do
    case Oli.Activities.Model.Feedback.parse(feedback) do
      {:ok, feedback} ->
        {:ok,
         %Oli.Activities.Model.FeedbackAction{
           id: id,
           score: score,
           feedback: feedback
         }}

      error ->
        error
    end
  end

  def parse(_) do
    {:error, "invalid feedback action"}
  end
end
