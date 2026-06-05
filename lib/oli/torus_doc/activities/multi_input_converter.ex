defmodule Oli.TorusDoc.Activities.MultiInputConverter do
  @moduledoc """
  Converts parsed Multi Input activities to Torus JSON format.
  """

  alias Oli.TorusDoc.ActivityConverter
  alias Oli.TorusDoc.Activities.MathExpressionSupport

  def convert(activity) when is_map(activity) do
    inputs = activity.multi_input_attributes[:inputs] || []
    input_ids = Enum.map(inputs, &input_id/1)

    with :ok <- validate_inputs(inputs),
         {:ok, stem} <- MathExpressionSupport.stem_with_input_refs(activity.stem_md, input_ids),
         {:ok, parts} <- build_parts(inputs),
         {:ok, model_inputs} <- build_inputs(inputs) do
      json = %{
        "type" => "Activity",
        "id" => activity.id || ActivityConverter.generate_id(),
        "title" => activity.title,
        "activityType" => activity.type,
        "stem" => stem,
        "choices" => [],
        "inputs" => model_inputs,
        "submitPerPart" => activity.multi_input_attributes[:submit_per_part] || false,
        "authoring" => %{
          "targeted" => [],
          "parts" => parts,
          "transformations" => [],
          "previewText" => MathExpressionSupport.preview_text(activity.stem_md)
        }
      }

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

  defp validate_inputs([]), do: {:error, "Multi-input activities require at least one input"}

  defp validate_inputs(inputs) do
    missing_id = Enum.find(inputs, &(not is_binary(&1["id"])))

    unsupported = Enum.reject(inputs, &MathExpressionSupport.math_expression_input?/1)

    case {missing_id, unsupported} do
      {nil, []} ->
        :ok

      {%{} = input, _} ->
        {:error, "Multi-input math_expression inputs require a string id: #{inspect(input)}"}

      {_, [input | _]} ->
        {:error,
         "First-class multi-input TorusDoc currently supports math_expression inputs. Unsupported input #{inspect(input_id(input))}"}
    end
  end

  defp build_inputs(inputs) do
    inputs
    |> Enum.reduce_while({:ok, []}, fn input, {:ok, acc} ->
      math_config = input["math_expression"] || %{}

      with {:ok, subtype} <- MathExpressionSupport.subtype(input) do
        model_input =
          %{
            "id" => input_id(input),
            "partId" => part_id(input),
            "inputType" => "math_expression",
            "itemConfig" => MathExpressionSupport.item_config(subtype, math_config)
          }
          |> maybe_put("size", input["size"])

        {:cont, {:ok, [model_input | acc]}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, converted} -> {:ok, Enum.reverse(converted)}
      error -> error
    end
  end

  defp build_parts(inputs) do
    inputs
    |> Enum.reduce_while({:ok, []}, fn input, {:ok, acc} ->
      math_config = input["math_expression"] || %{}

      with {:ok, responses} <-
             MathExpressionSupport.responses(input, math_config,
               correct_feedback: "Correct",
               incorrect_feedback: "Incorrect"
             ) do
        part =
          %{
            "id" => part_id(input),
            "scoringStrategy" => input["scoring_strategy"] || "best",
            "gradingApproach" => "automatic",
            "responses" => responses,
            "hints" => []
          }
          |> maybe_put("outOf", input["out_of"])

        {:cont, {:ok, [part | acc]}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, converted} -> {:ok, Enum.reverse(converted)}
      error -> error
    end
  end

  defp input_id(%{"id" => id}) when is_binary(id), do: id
  defp input_id(_), do: ActivityConverter.generate_id()

  defp part_id(%{"part_id" => part_id}) when is_binary(part_id), do: part_id
  defp part_id(%{"partId" => part_id}) when is_binary(part_id), do: part_id
  defp part_id(input), do: input_id(input)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
