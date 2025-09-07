defmodule Oli.TorusDoc.Activities.MCQConverter do
  @moduledoc """
  Converts parsed MCQ activities to Torus JSON format.
  """

  alias Oli.TorusDoc.ActivityConverter
  alias Oli.TorusDoc.Markdown.MarkdownParser

  @doc """
  Converts a parsed MCQ activity to Torus JSON format.

  Returns `{:ok, json}` on success or `{:error, reason}` on failure.
  """
  def convert(activity) when is_map(activity) do
    with {:ok, stem} <- ActivityConverter.convert_stem(activity.stem_md),
         {:ok, choices} <- convert_choices(activity.mcq_attributes.choices),
         {:ok, _hints} <- ActivityConverter.convert_hints(activity.hints),
         {:ok, part} <- build_part(activity, choices) do
      json = %{
        "type" => "Activity",
        "id" => activity.id || ActivityConverter.generate_id(),
        "title" => activity.title,
        "activityType" => activity.type || "oli_multiple_choice",
        "stem" => stem,
        "choices" => choices,
        "authoring" => %{
          "version" => 2,
          "targeted" => [],
          "parts" => [part],
          "transformations" => build_transformations(activity.mcq_attributes),
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

  defp convert_choices(choices) when is_list(choices) do
    choices
    |> Enum.reduce_while({:ok, []}, fn choice, {:ok, acc} ->
      case convert_choice(choice) do
        {:ok, converted} -> {:cont, {:ok, [converted | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      error -> error
    end
  end

  defp convert_choice(choice) do
    case MarkdownParser.parse(choice.body_md) do
      {:ok, content} ->
        {:ok,
         %{
           "id" => choice.id,
           "content" => content
         }}

      {:error, reason} ->
        {:error, "Failed to parse choice markdown: #{reason}"}
    end
  end

  defp build_part(activity, choices) do
    with {:ok, responses} <- build_responses(activity, choices),
         {:ok, hints} <- ActivityConverter.convert_hints(activity.hints),
         {:ok, explanation} <- convert_explanation(activity.explanation_md) do
      part = %{
        "id" => ActivityConverter.generate_id(),
        "scoringStrategy" => "average",
        "responses" => responses,
        "hints" => hints
      }

      # Add explanation if present
      part =
        case explanation do
          nil -> part
          exp -> Map.put(part, "explanation", exp)
        end

      {:ok, part}
    end
  end

  defp build_responses(activity, _choices) do
    # Build responses based on choices
    responses =
      activity.mcq_attributes.choices
      |> Enum.map(fn choice ->
        # Create a response for each choice
        # Use proper rule format for evaluation: input like {A}
        rule = "input like {" <> choice.id <> "}"

        with {:ok, feedback} <- ActivityConverter.convert_feedback(choice.feedback_md) do
          {:ok,
           %{
             "id" => ActivityConverter.generate_id(),
             "rule" => rule,
             "score" => choice.score,
             "feedback" =>
               feedback ||
                 %{
                   "id" => ActivityConverter.generate_id(),
                   "content" => []
                 }
           }}
        end
      end)
      |> Enum.reduce_while({:ok, []}, fn
        {:ok, response}, {:ok, acc} -> {:cont, {:ok, [response | acc]}}
        {:error, reason}, _ -> {:halt, {:error, reason}}
      end)

    case responses do
      {:ok, choice_responses} ->
        # Add catch-all response for incorrect answers
        catch_all = build_catch_all_response(activity.incorrect_feedback_md)
        {:ok, Enum.reverse(choice_responses) ++ [catch_all]}

      error ->
        error
    end
  end

  defp build_catch_all_response(nil) do
    %{
      "id" => ActivityConverter.generate_id(),
      "rule" => ".*",
      "score" => 0,
      "feedback" => %{
        "id" => ActivityConverter.generate_id(),
        "content" => []
      }
    }
  end

  defp build_catch_all_response(incorrect_feedback_md) do
    case ActivityConverter.convert_feedback(incorrect_feedback_md) do
      {:ok, feedback} ->
        %{
          "id" => ActivityConverter.generate_id(),
          "rule" => ".*",
          "score" => 0,
          "feedback" => feedback
        }

      {:error, _} ->
        build_catch_all_response(nil)
    end
  end

  defp convert_explanation(nil), do: {:ok, nil}

  defp convert_explanation(explanation_md) do
    ActivityConverter.convert_feedback(explanation_md)
  end

  defp build_transformations(%{shuffle: true}) do
    [
      %{
        "id" => ActivityConverter.generate_id(),
        "path" => "choices",
        "operation" => "shuffle",
        "firstAttemptOnly" => true
      }
    ]
  end

  defp build_transformations(_), do: []
end
