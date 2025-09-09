defmodule Oli.GenAI.Agent.ActionComparator do
  @moduledoc """
  Utilities for comparing and normalizing agent actions.
  """

  @large_json_threshold 200

  @type action :: map()

  @doc """
  Checks if two actions are identical.
  """
  @spec identical?(action(), action()) :: boolean()
  def identical?(%{type: "tool", name: name1, args: args1}, %{
        type: "tool",
        name: name2,
        args: args2
      }) do
    name1 == name2 and key_args_match?(args1, args2)
  end

  def identical?(action1, action2) do
    normalize(action1) == normalize(action2)
  end

  @doc """
  Normalizes an action for comparison purposes.
  """
  @spec normalize(action()) :: term()
  def normalize(%{type: "tool", name: name, args: args}) do
    normalized_args =
      case args do
        args when is_map(args) ->
          Map.reject(args, fn {_k, v} -> is_large_json?(v) end)

        args ->
          args
      end

    {:tool, name, normalized_args}
  end

  def normalize(%{type: type, content: content}) when type in ["message"] do
    normalized_content =
      case content do
        content when is_binary(content) ->
          String.slice(content, 0, 50)

        content ->
          content
      end

    {:message, normalized_content}
  end

  def normalize(%{type: type} = action) do
    {type, Map.drop(action, [:type])}
  end

  def normalize(action), do: action

  @doc """
  Compares key arguments, ignoring large JSON payloads.
  """
  @spec key_args_match?(term(), term()) :: boolean()
  def key_args_match?(args1, args2) when is_map(args1) and is_map(args2) do
    filtered_args1 = Map.reject(args1, fn {_k, v} -> is_large_json?(v) end)
    filtered_args2 = Map.reject(args2, fn {_k, v} -> is_large_json?(v) end)
    filtered_args1 == filtered_args2
  end

  def key_args_match?(args1, args2), do: args1 == args2

  @doc """
  Checks if a value appears to be a large JSON string.
  """
  @spec is_large_json?(term()) :: boolean()
  def is_large_json?(value) when is_binary(value) and byte_size(value) > @large_json_threshold do
    is_json_string?(value)
  end

  def is_large_json?(_), do: false

  @spec is_json_string?(String.t()) :: boolean()
  defp is_json_string?(value) do
    # Use simple heuristic for performance - JSON parsing can be expensive
    String.starts_with?(value, "{") and String.ends_with?(value, "}")
  end
end
