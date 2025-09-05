defmodule Oli.TorusDoc.ActivityParser do
  @moduledoc """
  Base parser for TorusDoc Activity YAML format.

  Provides common parsing functionality for all activity types.
  """

  @doc """
  Parses an activity YAML string into a structured representation.

  Returns `{:ok, activity}` on success or `{:error, reason}` on failure.
  """
  def parse(yaml_string) when is_binary(yaml_string) do
    case YamlElixir.read_from_string(yaml_string) do
      {:ok, data} ->
        parse_activity(data)

      {:error, reason} ->
        {:error, "YAML parsing failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Parses activity data directly (already parsed from YAML).

  Returns `{:ok, activity}` on success or `{:error, reason}` on failure.
  """
  def parse_activity(data) when is_map(data) do
    with {:ok, type} <- validate_activity_type(data),
         {:ok, base_attrs} <- parse_base_attributes(data),
         {:ok, specific_attrs} <- parse_specific_attributes(type, data) do
      {:ok, Map.merge(base_attrs, specific_attrs)}
    end
  end

  def parse_activity(_), do: {:error, "Invalid activity structure: expected a map"}

  defp validate_activity_type(%{"type" => type}) when is_binary(type) do
    cond do
      type == "oli_multi_choice" -> {:ok, :mcq}
      # Support both variants
      type == "oli_multiple_choice" -> {:ok, :mcq}
      type == "oli_short_answer" -> {:ok, :short_answer}
      type == "oli_check_all_that_apply" -> {:ok, :cata}
      type == "oli_ordering" -> {:ok, :ordering}
      type == "oli_multi_input" -> {:ok, :multi_input}
      true -> {:error, "Unsupported activity type: #{type}"}
    end
  end

  defp validate_activity_type(_), do: {:error, "Missing or invalid activity type"}

  defp parse_base_attributes(data) do
    # stem_md is required for all activities
    case data["stem_md"] do
      nil ->
        {:error, "Missing required field: stem_md"}

      stem_md when is_binary(stem_md) ->
        {:ok,
         %{
           type: data["type"],
           id: data["id"],
           title: data["title"],
           objectives: data["objectives"] || [],
           tags: data["tags"] || [],
           stem_md: stem_md,
           explanation_md: data["explanation_md"],
           incorrect_feedback_md: data["incorrect_feedback_md"],
           hints: parse_hints(data["hints"] || []),
           metadata: extract_metadata(data)
         }}

      _ ->
        {:error, "Field stem_md must be a string"}
    end
  end

  defp parse_hints(hints) when is_list(hints) do
    Enum.map(hints, fn
      %{"body_md" => body} -> %{body_md: body}
      hint when is_binary(hint) -> %{body_md: hint}
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_hints(_), do: []

  defp parse_specific_attributes(:mcq, data) do
    case Oli.TorusDoc.Activities.MCQParser.parse_specific(data) do
      {:ok, attrs} -> {:ok, %{activity_type: :mcq, mcq_attributes: attrs}}
      error -> error
    end
  end

  defp parse_specific_attributes(:short_answer, data) do
    {:ok,
     %{
       activity_type: :short_answer,
       short_answer_attributes: %{
         input_type: data["input_type"] || "text"
       }
     }}
  end

  defp parse_specific_attributes(:cata, data) do
    case Oli.TorusDoc.Activities.CATAParser.parse_specific(data) do
      {:ok, attrs} -> {:ok, %{activity_type: :cata, cata_attributes: attrs}}
      error -> error
    end
  end

  defp parse_specific_attributes(:ordering, data) do
    case Oli.TorusDoc.Activities.OrderingParser.parse_specific(data) do
      {:ok, attrs} -> {:ok, %{activity_type: :ordering, ordering_attributes: attrs}}
      error -> error
    end
  end

  defp parse_specific_attributes(:multi_input, data) do
    {:ok,
     %{
       activity_type: :multi_input,
       multi_input_attributes: %{
         parts: data["parts"] || []
       }
     }}
  end

  defp parse_specific_attributes(type, _data) do
    {:error, "Parser not implemented for activity type: #{type}"}
  end

  defp extract_metadata(data) do
    data
    |> Map.drop([
      "type",
      "id",
      "title",
      "objectives",
      "tags",
      "stem_md",
      "explanation_md",
      "incorrect_feedback_md",
      "hints",
      "choices",
      "shuffle",
      "input_type",
      "parts"
    ])
    |> case do
      empty when empty == %{} -> nil
      metadata -> metadata
    end
  end
end
