defmodule Oli.Activities.Model.Part do
  defstruct [
    :id,
    :scoring_strategy,
    :responses,
    :hints,
    :parts,
    :triggers,
    :grading_approach,
    :out_of,
    :explanation,
    :targets
  ]

  @grading_approaches MapSet.new(["automatic", "manual"])

  def parse(%{"id" => id} = part) do
    scoring_strategy =
      Map.get(part, "scoringStrategy", Oli.Resources.ScoringStrategy.get_id_by_type("average"))

    hints = Map.get(part, "hints", [])
    parts = Map.get(part, "parts", [])
    responses = Map.get(part, "responses", [])
    explanation = Map.get(part, "explanation")
    targets = Map.get(part, "targets", [])
    triggers = Map.get(part, "triggers", [])

    grading_approach_str =
      Map.get(part, "gradingApproach", "automatic")

    grading_approach =
      case MapSet.member?(@grading_approaches, grading_approach_str) do
        true -> String.to_atom(grading_approach_str)
        false -> :automatic
      end

    out_of = Map.get(part, "outOf")

    with {:ok, responses} <- Oli.Activities.Model.Response.parse(responses),
         {:ok, hints} <- Oli.Activities.Model.Hint.parse(hints),
         {:ok, parts} <- Oli.Activities.Model.Part.parse(parts),
         {:ok, triggers} <- Oli.Activities.Model.Trigger.parse(triggers),
         {:ok, explanation} <- Oli.Activities.Model.Explanation.parse(explanation) do
      {:ok,
       %Oli.Activities.Model.Part{
         responses: responses,
         hints: hints,
         parts: parts,
         triggers: triggers,
         id: id,
         scoring_strategy: scoring_strategy,
         grading_approach: grading_approach,
         out_of: out_of,
         explanation: explanation,
         targets: targets
       }}
    else
      error -> error
    end
  end

  def parse(parts) when is_list(parts) do
    Enum.map(parts, &parse/1)
    |> Oli.Activities.ParseUtils.items_or_errors()
  end

  def parse(_) do
    {:error, "invalid part"}
  end

  def parse() do
    {:error, "invalid part"}
  end
end
