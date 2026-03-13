defmodule Oli.GenAI.Completions.Function do
  @derive Jason.Encoder
  defstruct [
    :name,
    :description,
    :parameters
  ]

  def new(name, description, parameters) do
    %__MODULE__{
      name: name,
      description: description,
      parameters: parameters
    }
  end

  @doc """
  From a library of available functions (in the form of a list of Function structs),
  takes a function name as a string in the form of "function_name" and a
  map of arguments, executes that function with the arguments and prepares the returned
  result for sending back to an LLM based agent.

  This function returns the result as a string, JSON encoded map, or list, wrapped in a
  tuple `{:ok, result}` or an error tuple `{:error, reason}` if the function name is invalid.
  """
  def call(available_functions, name, arguments_as_map) do
    case verify_module_and_function(available_functions, name) do
      {:ok, function, module, function_name} ->
        case apply(module, function_name, [merge_trusted_arguments(function, arguments_as_map)]) do
          result when is_binary(result) -> {:ok, result}
          result when is_map(result) -> {:ok, Jason.encode!(result)}
          result when is_list(result) -> {:ok, Jason.encode!(%{result: result})}
          result -> {:ok, Kernel.to_string(result)}
        end

      e ->
        e
    end
  end

  # Looks up the module for a given function name in the available functions
  defp verify_module_and_function(available_functions, name) do
    as_map =
      Enum.reduce(available_functions, %{}, fn function, acc ->
        Map.put(acc, function.name, function)
      end)

    case Map.get(as_map, name) do
      nil ->
        {:error, :invalid_function_name}

      function ->
        verify_full_name(function)
    end
  end

  defp verify_full_name(%{full_name: nil}) do
    {:error, :invalid_function_name}
  end

  defp verify_full_name(%{full_name: full_name} = function) do
    case String.split(full_name, ".") do
      parts when is_list(parts) ->
        parse_full_name(function, parts)

      _ ->
        {:error, :invalid_function_name}
    end
  end

  defp parse_full_name(function, parts) do
    with true <- Enum.count(parts) >= 2,
         true <- Enum.all?(parts, &(&1 != "")),
         module_name <- parts |> Enum.drop(-1) |> Enum.join("."),
         {:ok, module} <- safe_to_existing_atom(module_name),
         {:ok, name} <- safe_to_existing_atom(List.last(parts)),
         true <- Code.ensure_loaded?(module) do
      {:ok, function, module, name}
    else
      _ -> {:error, :invalid_function_name}
    end
  end

  defp safe_to_existing_atom(value) when is_binary(value) do
    try do
      {:ok, String.to_existing_atom(value)}
    rescue
      ArgumentError -> {:error, :invalid_function_name}
    end
  end

  defp merge_trusted_arguments(function, arguments_as_map) do
    Map.merge(arguments_as_map, Map.get(function, :trusted_arguments, %{}))
  end
end
