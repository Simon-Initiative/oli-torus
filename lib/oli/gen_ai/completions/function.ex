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
      {:ok, module, function_name} ->
        case apply(module, function_name, [arguments_as_map]) do
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

    case Map.get(as_map, name).full_name do
      nil ->
        {:error, :invalid_function_name}

      full_name ->
        case String.split(full_name, ".") do
          parts when is_list(parts) ->
            module_parts = Enum.take(parts, Enum.count(parts) - 1)
            name = Enum.at(parts, -1) |> String.to_existing_atom()

            # Join the module parts and convert to an atom
            module =
              Enum.join(module_parts, ".")
              |> String.to_existing_atom()

            # ensure that it is a valid module that is loaded
            if Code.ensure_loaded?(module) do
              {:ok, module, name}
            else
              {:error, :invalid_function_name}
            end

          _ ->
            {:error, :invalid_function_name}
        end
    end
  end
end
