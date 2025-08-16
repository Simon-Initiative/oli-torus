defmodule Oli.GenAI.Tools.ActivityTestEvalTool do
  @moduledoc """
  MCP tool for testing activity evaluation.

  This tool allows external AI agents to test activity JSON by simulating
  student submissions and verifying the correct responses and feedback are returned.
  """

  use Hermes.Server.Component, type: :tool

  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Hermes.Server.Response

  schema do
    field :activity_json, :string, required: true, description: "JSON string containing the activity model to test"
    field :activity_type, :string, required: true, description: "The activity type slug (e.g., 'oli_multiple_choice')"
    field :part_inputs, :string, required: true, description: "JSON encoded strin of a list of objects containing part inputs to evaluate. Each object should have 'part_id' and 'input' fields"
  end

  @impl true
  def execute(%{activity_json: activity_json, activity_type: activity_type, part_inputs: part_inputs}, frame) do

    part_inputs = Jason.decode!(part_inputs)

    case test_activity_evaluation(activity_json, activity_type, part_inputs) do
      {:ok, evaluations} ->

        response_text = format_evaluations(evaluations)
        {:reply, Response.text(Response.tool(), response_text), frame}

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), "Test evaluation failed: #{format_error(reason)}"), frame}
    end
  end

  # Performs test evaluation of the activity
  defp test_activity_evaluation(activity_json, activity_type, part_inputs) do
    # Convert part_inputs if needed (handle both string and atom keys)
    normalized_inputs = normalize_part_inputs(part_inputs)

    Evaluate.perform_test_eval(activity_json, activity_type, normalized_inputs)
  end

  # Normalize part inputs to ensure consistent format
  defp normalize_part_inputs(part_inputs) when is_list(part_inputs) do
    Enum.map(part_inputs, fn input ->
      %{
        "part_id" => get_field(input, "part_id"),
        "input" => get_field(input, "input")
      }
    end)
  end

  defp get_field(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, String.to_atom(key))
  end

  # Format evaluation results for display
  defp format_evaluations(evaluations) do
    evaluations_json = Jason.encode!(evaluations, pretty: true)

    summary = Enum.map(evaluations, fn eval ->
      part_id = Map.get(eval, :part_id)

      if Map.has_key?(eval, :error) do
        "Part #{part_id}: ERROR - #{Map.get(eval, :error)}"
      else
        score = Map.get(eval, :score, 0)
        out_of = Map.get(eval, :out_of, 1)
        feedback = Map.get(eval, :feedback)

        feedback_text = case feedback do
          %{"content" => content} when is_list(content) ->
            extract_text_from_content(content)
          _ ->
            inspect(feedback)
        end

        "Part #{part_id}: Score #{score}/#{out_of} - Feedback: #{feedback_text}"
      end
    end)
    |> Enum.join("\n")

    """
    Test Evaluation Results:
    #{summary}

    Full Response:
    #{evaluations_json}
    """
  end

  # Extract text from Slate-style content structure
  defp extract_text_from_content(content) when is_list(content) do
    content
    |> Enum.map(&extract_text_from_element/1)
    |> Enum.join(" ")
  end

  defp extract_text_from_element(%{"children" => children}) when is_list(children) do
    children
    |> Enum.map(&extract_text_from_node/1)
    |> Enum.join("")
  end
  defp extract_text_from_element(_), do: ""

  defp extract_text_from_node(%{"text" => text}), do: text
  defp extract_text_from_node(%{"children" => children}) when is_list(children) do
    extract_text_from_content(children)
  end
  defp extract_text_from_node(_), do: ""

  # Format error messages
  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)
end
