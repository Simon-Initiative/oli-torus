defmodule Oli.TorusDoc.ActivityConverter do
  @moduledoc """
  Converts parsed TorusDoc activity structures to Torus JSON format.

  This module is responsible for transforming the intermediate representation
  from ActivityParser into the Torus JSON schema format.
  """

  alias Oli.TorusDoc.Markdown.MarkdownParser

  @doc """
  Converts a parsed activity structure to Torus JSON format.

  Returns `{:ok, json}` on success or `{:error, reason}` on failure.
  """
  def to_torus_json(parsed_activity) when is_map(parsed_activity) do
    # Handle both :type and :activity_type fields
    activity_type = Map.get(parsed_activity, :type) || Map.get(parsed_activity, :activity_type)

    # The parser produces :activity_type as symbols but :type as strings
    case activity_type do
      :mcq -> convert_mcq(parsed_activity)
      :short_answer -> convert_short_answer(parsed_activity)
      :cata -> convert_cata(parsed_activity)
      :ordering -> convert_ordering(parsed_activity)
      :multi_input -> convert_multi_input(parsed_activity)
      "oli_multi_choice" -> convert_mcq(parsed_activity)
      "oli_multiple_choice" -> convert_mcq(parsed_activity)
      "oli_short_answer" -> convert_short_answer(parsed_activity)
      "oli_check_all_that_apply" -> convert_cata(parsed_activity)
      "oli_ordering" -> convert_ordering(parsed_activity)
      "oli_multi_input" -> convert_multi_input(parsed_activity)
      _ -> {:error, "Unknown activity type: #{inspect(activity_type)}"}
    end
  end

  def to_torus_json(_) do
    {:error, "Invalid parsed activity structure"}
  end

  defp convert_mcq(activity) do
    case Oli.TorusDoc.Activities.MCQConverter.convert(activity) do
      {:ok, json} -> {:ok, json}
      error -> error
    end
  end

  defp convert_short_answer(activity) do
    case Oli.TorusDoc.Activities.ShortAnswerConverter.convert(activity) do
      {:ok, json} -> {:ok, json}
      error -> error
    end
  end

  defp convert_cata(_activity) do
    {:error, "CATA converter not yet implemented"}
  end

  defp convert_ordering(_activity) do
    {:error, "Ordering converter not yet implemented"}
  end

  defp convert_multi_input(_activity) do
    {:error, "Multi-input converter not yet implemented"}
  end

  @doc """
  Converts stem markdown to rich text content.
  """
  def convert_stem(stem_md) when is_binary(stem_md) do
    case MarkdownParser.parse(stem_md) do
      {:ok, content_elements} ->
        {:ok,
         %{
           "id" => generate_id(),
           "content" => content_elements
         }}

      {:error, reason} ->
        {:error, "Failed to parse stem markdown: #{reason}"}
    end
  end

  def convert_stem(_), do: {:error, "Stem must be a string"}

  @doc """
  Converts hints to the Torus JSON format.
  """
  def convert_hints(hints) when is_list(hints) do
    hints
    |> Enum.reduce_while({:ok, []}, fn hint, {:ok, acc} ->
      case convert_hint(hint) do
        {:ok, converted} -> {:cont, {:ok, [converted | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      error -> error
    end
  end

  def convert_hints(_), do: {:ok, []}

  defp convert_hint(%{body_md: markdown}) when is_binary(markdown) do
    case MarkdownParser.parse(markdown) do
      {:ok, content} ->
        {:ok,
         %{
           "id" => generate_id(),
           "content" => content
         }}

      {:error, reason} ->
        {:error, "Failed to parse hint markdown: #{reason}"}
    end
  end

  defp convert_hint(_), do: {:error, "Invalid hint structure"}

  @doc """
  Converts feedback markdown to rich text content.
  """
  def convert_feedback(nil), do: {:ok, nil}

  def convert_feedback(feedback_md) when is_binary(feedback_md) do
    case MarkdownParser.parse(feedback_md) do
      {:ok, content} ->
        {:ok,
         %{
           "id" => generate_id(),
           "content" => content
         }}

      {:error, reason} ->
        {:error, "Failed to parse feedback markdown: #{reason}"}
    end
  end

  @doc """
  Creates a basic response structure.
  """
  def make_response(rule, score, feedback \\ nil) do
    response = %{
      "id" => generate_id(),
      "rule" => rule,
      "score" => score,
      "feedback" => %{
        "id" => generate_id(),
        "content" => []
      }
    }

    case feedback do
      nil ->
        response

      feedback_content ->
        Map.put(response, "feedback", feedback_content)
    end
  end

  @doc """
  Generates a unique ID for elements.
  """
  def generate_id do
    "gen_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end

  @doc """
  Convenience function that parses YAML and converts to Torus JSON in one step.
  """
  def from_yaml(yaml_string) do
    alias Oli.TorusDoc.ActivityParser

    with {:ok, parsed} <- ActivityParser.parse(yaml_string),
         {:ok, json} <- to_torus_json(parsed) do
      {:ok, json}
    end
  end
end
