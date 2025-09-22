defmodule Oli.TorusDoc.Activities.CATAParser do
  @moduledoc """
  Parser for Check All That Apply (CATA) specific attributes.

  This is a placeholder implementation - full support coming soon.
  """

  @doc """
  Parses CATA-specific attributes from the activity data.

  Returns `{:ok, attributes}` on success or `{:error, reason}` on failure.
  """
  def parse_specific(data) when is_map(data) do
    # For now, just parse choices similar to MCQ
    # Real implementation would handle correct combinations
    with {:ok, choices} <- parse_choices(data["choices"] || []) do
      {:ok,
       %{
         shuffle: data["shuffle"] || false,
         choices: choices,
         correct_combinations: data["correct_combinations"] || []
       }}
    end
  end

  defp parse_choices(choices) when is_list(choices) do
    choices
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {choice, index}, {:ok, acc} ->
      case parse_choice(choice) do
        {:ok, parsed_choice} ->
          {:cont, {:ok, [parsed_choice | acc]}}

        {:error, reason} ->
          {:halt, {:error, "Error in choice #{index + 1}: #{reason}"}}
      end
    end)
    |> case do
      {:ok, reversed_choices} -> {:ok, Enum.reverse(reversed_choices)}
      error -> error
    end
  end

  defp parse_choices(_), do: {:error, "Choices must be a list"}

  defp parse_choice(%{"id" => id, "body_md" => body} = choice)
       when is_binary(id) and is_binary(body) do
    {:ok,
     %{
       id: id,
       body_md: body,
       feedback_md: choice["feedback_md"]
     }}
  end

  defp parse_choice(_) do
    {:error, "Choice must have 'id' and 'body_md' fields"}
  end
end
