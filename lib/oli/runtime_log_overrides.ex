defmodule Oli.RuntimeLogOverrides do
  @moduledoc """
  Local-node runtime log override management for admin-applied overrides.
  """

  require Logger

  alias Oli.RuntimeLogOverrides.Registry

  @type override_state :: %{modules: list(map()), processes: list(map())}
  @type error_reason :: :invalid_level | :invalid_module

  @spec list_overrides() :: override_state()
  def list_overrides do
    Registry.list_overrides()
  end

  @spec set_module_level(String.t(), atom() | String.t()) ::
          {:ok, override_state()} | {:error, error_reason()}
  def set_module_level(module_name, level) do
    with {:ok, module} <- parse_module(module_name),
         {:ok, validated_level} <- validate_level(level),
         :ok <- Logger.put_module_level(module, validated_level),
         {:ok, _override} <- Registry.put_module_override(module, validated_level) do
      Logger.info(
        "Runtime log override set for module=#{inspect(module)} level=#{validated_level} node=#{node()}"
      )

      {:ok, list_overrides()}
    else
      {:error, _reason} = error ->
        log_failed_module_override("set", module_name, level, error)
        error
    end
  end

  @spec clear_module_level(String.t()) :: {:ok, override_state()} | {:error, :invalid_module}
  def clear_module_level(module_name) do
    with {:ok, module} <- parse_module(module_name),
         :ok <- Logger.delete_module_level(module),
         :ok <- Registry.delete_module_override(module) do
      Logger.info("Runtime log override cleared for module=#{inspect(module)} node=#{node()}")

      {:ok, list_overrides()}
    else
      {:error, _reason} = error ->
        log_failed_module_override("clear", module_name, nil, error)
        error
    end
  end

  defp parse_module(module_name) when is_binary(module_name) do
    trimmed_name = String.trim(module_name)

    if trimmed_name == "" do
      {:error, :invalid_module}
    else
      normalized_name =
        case String.starts_with?(trimmed_name, "Elixir.") do
          true -> trimmed_name
          false -> "Elixir." <> trimmed_name
        end

      try do
        module = String.to_existing_atom(normalized_name)

        if Code.ensure_loaded?(module) do
          {:ok, module}
        else
          {:error, :invalid_module}
        end
      rescue
        ArgumentError ->
          {:error, :invalid_module}
      end
    end
  end

  defp parse_module(_module_name), do: {:error, :invalid_module}

  defp validate_level(level) when is_binary(level) do
    case String.trim(level) do
      "" ->
        {:error, :invalid_level}

      trimmed_level ->
        try do
          trimmed_level
          |> String.to_existing_atom()
          |> validate_level()
        rescue
          ArgumentError -> {:error, :invalid_level}
        end
    end
  end

  defp validate_level(level) when is_atom(level) do
    case level in Logger.levels() do
      true -> {:ok, level}
      false -> {:error, :invalid_level}
    end
  end

  defp validate_level(_level), do: {:error, :invalid_level}

  defp log_failed_module_override(action, module_name, level, {:error, reason}) do
    Logger.warning(
      "Runtime log override #{action} failed module=#{inspect(module_name)} level=#{inspect(level)} reason=#{inspect(reason)} node=#{node()}"
    )
  end
end
