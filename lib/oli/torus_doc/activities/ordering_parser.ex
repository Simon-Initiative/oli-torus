defmodule Oli.TorusDoc.Activities.OrderingParser do
  @moduledoc """
  Parser for Ordering activity specific attributes.

  This is a placeholder implementation - full support coming soon.
  """

  @doc """
  Parses Ordering-specific attributes from the activity data.

  Returns `{:ok, attributes}` on success or `{:error, reason}` on failure.
  """
  def parse_specific(data) when is_map(data) do
    # For now, parse similar to MCQ with ordered choices
    # Real implementation would handle correct ordering
    with {:ok, choices} <- parse_choices(data["choices"] || []) do
      {:ok,
       %{
         # Ordering typically shuffles by default
         shuffle: data["shuffle"] || true,
         choices: choices,
         correct_order: data["correct_order"] || Enum.map(choices, & &1.id)
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
       # Optional explicit order
       order: choice["order"]
     }}
  end

  defp parse_choice(_) do
    {:error, "Choice must have 'id' and 'body_md' fields"}
  end
end
