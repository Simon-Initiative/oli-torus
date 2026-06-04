defmodule Oli.Activities.Model.Response do
  @derive Jason.Encoder
  defstruct [:id, :rule, :match_config, :score, :feedback, :show_page, :correct]

  alias Oli.Activities.Model.Feedback

  @type t :: %__MODULE__{
          id: String.t(),
          rule: String.t(),
          match_config: map() | nil,
          score: number(),
          feedback: term(),
          show_page: String.t() | nil,
          correct: boolean() | nil
        }

  def parse(%{"id" => id, "score" => score, "feedback" => feedback} = response) do
    with {:ok, rule} <- parse_rule(response),
         {:ok, feedback} <- Feedback.parse(feedback) do
      {:ok,
       %__MODULE__{
         id: id,
         rule: rule,
         match_config: Map.get(response, "matchConfig"),
         score: score,
         feedback: feedback,
         show_page: Map.get(response, "showPage", nil),
         correct: Map.get(response, "correct")
       }}
    end
  end

  def parse(responses) when is_list(responses) do
    Enum.map(responses, &parse/1)
    |> Oli.Activities.ParseUtils.items_or_errors()
  end

  def parse(_) do
    {:error, "invalid response"}
  end

  defp parse_rule(%{"rule" => rule}) when is_binary(rule), do: {:ok, rule}
  defp parse_rule(%{"matchConfig" => match_config}) when not is_nil(match_config), do: {:ok, ""}
  defp parse_rule(_), do: {:error, "invalid response"}
end
