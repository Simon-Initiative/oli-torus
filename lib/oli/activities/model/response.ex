defmodule Oli.Activities.Model.Response do

  @derive Jason.Encoder
  defstruct [:id, :rule, :score, :feedback, :show_page]

  def parse(%{"id" => id, "rule" => rule, "score" => score, "feedback" => feedback} = response) do
    case Oli.Activities.Model.Feedback.parse(feedback) do
      {:ok, feedback} ->
        {:ok,
         %Oli.Activities.Model.Response{
           id: id,
           rule: rule,
           score: score,
           feedback: feedback,
           show_page: Map.get(response, "showPage", nil)
         }}

      error ->
        error
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
