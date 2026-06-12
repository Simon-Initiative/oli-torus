defmodule Oli.TorusDoc.Activities.ShortAnswerConverter do
  @moduledoc """
  Converts parsed Short Answer activities to Torus JSON format.

  This is a placeholder implementation - full support coming soon.
  """

  alias Oli.TorusDoc.ActivityConverter
  alias Oli.TorusDoc.Activities.MathExpressionSupport

  @doc """
  Converts a parsed Short Answer activity to Torus JSON format.

  Returns `{:ok, json}` on success or `{:error, reason}` on failure.
  """
  def convert(activity) when is_map(activity) do
    with {:ok, stem} <- ActivityConverter.convert_stem(activity.stem_md),
         {:ok, hints} <- ActivityConverter.convert_hints(activity.hints),
         {:ok, question_type, question_config, responses} <- build_responses(activity) do
      json =
        %{
          "type" => "Activity",
          "id" => activity.id || ActivityConverter.generate_id(),
          "title" => activity.title,
          "activityType" => activity.type,
          "stem" => stem,
          "inputType" => input_type(activity),
          "authoring" => %{
            "parts" => [
              %{
                "id" => ActivityConverter.generate_id(),
                "scoringStrategy" => scoring_strategy(activity),
                "responses" => responses,
                "hints" => hints
              }
            ],
            "transformations" => [],
            "previewText" => ""
          }
        }
        |> maybe_put_item_config(question_type, question_config)

      # Add optional fields
      json =
        if activity.objectives && activity.objectives != [] do
          Map.put(json, "objectives", %{"attached" => activity.objectives})
        else
          json
        end

      json =
        if activity.tags && activity.tags != [] do
          Map.put(json, "tags", activity.tags)
        else
          json
        end

      {:ok, json}
    end
  end

  defp input_type(activity) do
    attributes = stringify_keys(activity.short_answer_attributes)

    if MathExpressionSupport.math_expression_input?(attributes) do
      "math_expression"
    else
      attributes["input_type"] || "text"
    end
  end

  defp scoring_strategy(activity) do
    attributes = stringify_keys(activity.short_answer_attributes)

    attributes["scoring_strategy"] ||
      if MathExpressionSupport.math_expression_input?(attributes) do
        "best"
      else
        "average"
      end
  end

  defp build_responses(activity) do
    attributes = stringify_keys(activity.short_answer_attributes)

    if MathExpressionSupport.math_expression_input?(attributes) do
      math_config = attributes["math_expression"] || %{}

      with {:ok, subtype} <- MathExpressionSupport.subtype(attributes),
           {:ok, responses} <-
             MathExpressionSupport.responses(attributes, math_config,
               correct_feedback: "Correct",
               incorrect_feedback: activity.incorrect_feedback_md || "Incorrect"
             ) do
        {:ok, subtype, math_config, responses}
      end
    else
      {:ok, nil, nil,
       [
         %{
           "id" => ActivityConverter.generate_id(),
           "rule" => ".*",
           "score" => 1,
           "feedback" => %{
             "id" => ActivityConverter.generate_id(),
             "content" => []
           }
         }
       ]}
    end
  end

  defp maybe_put_item_config(json, nil, _config), do: json

  defp maybe_put_item_config(json, subtype, config) do
    Map.put(json, "itemConfig", MathExpressionSupport.item_config(subtype, config))
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify_keys(_), do: %{}
end
