defmodule Oli.TorusDoc.Activities.ShortAnswerConverter do
  @moduledoc """
  Converts parsed Short Answer activities to Torus JSON format.

  This is a placeholder implementation - full support coming soon.
  """

  alias Oli.TorusDoc.ActivityConverter

  @doc """
  Converts a parsed Short Answer activity to Torus JSON format.

  Returns `{:ok, json}` on success or `{:error, reason}` on failure.
  """
  def convert(activity) when is_map(activity) do
    with {:ok, stem} <- ActivityConverter.convert_stem(activity.stem_md),
         {:ok, hints} <- ActivityConverter.convert_hints(activity.hints) do
      json = %{
        "type" => "Activity",
        "id" => activity.id || ActivityConverter.generate_id(),
        "title" => activity.title,
        "activityType" => activity.type,
        "stem" => stem,
        "inputType" => activity.short_answer_attributes[:input_type] || "text",
        "authoring" => %{
          "parts" => [
            %{
              "id" => ActivityConverter.generate_id(),
              "scoringStrategy" => "average",
              "responses" => [
                # For now, create a single catch-all response
                # Real implementation would parse response patterns
                %{
                  "id" => ActivityConverter.generate_id(),
                  "rule" => ".*",
                  "score" => 1,
                  "feedback" => %{
                    "id" => ActivityConverter.generate_id(),
                    "content" => []
                  }
                }
              ],
              "hints" => hints
            }
          ],
          "transformations" => [],
          "previewText" => ""
        }
      }

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
end
