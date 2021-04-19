defmodule Oli.Activities.Model.Part do
  defstruct [:id, :scoring_strategy, :responses, :hints, :parts]

  def parse(
        %{
          "id" => id,
          "scoringStrategy" => scoring_strategy
        } = part
      ) do
    hints = Map.get(part, "hints", [])
    parts = Map.get(part, "parts", [])
    responses = Map.get(part, "responses", [])

    with {:ok, responses} <- Oli.Activities.Model.Response.parse(responses),
         {:ok, hints} <- Oli.Activities.Model.Hint.parse(hints),
         {:ok, parts} <- Oli.Activities.Model.Part.parse(parts) do
      {:ok,
       %Oli.Activities.Model.Part{
         responses: responses,
         hints: hints,
         parts: parts,
         id: id,
         scoring_strategy: scoring_strategy
       }}
    else
      error -> error
    end
  end

  def parse(parts) when is_list(parts) do
    Enum.map(parts, &parse/1)
    |> Oli.Activities.ParseUtils.items_or_errors()
  end

  def parse() do
    {:error, "invalid part"}
  end
end
