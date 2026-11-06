defmodule Oli.RuntimeLogOverrides.DebugRevertConfig do
  @moduledoc """
  Configuration for automatically reverting the global log level after an admin enables `:debug`.

  Values are read from the environment in `config/runtime.exs`:

    * `DEBUG_LOG_LEVEL_TIMEOUT_MINUTES` - minutes before `:debug` is reverted (default `30`)
    * `DEBUG_LOG_LEVEL_REVERT_LEVEL` - level restored after the timeout (default `warning`)
  """

  @default_timeout_minutes 30
  @default_revert_level :warning

  @type t :: [timeout_minutes: pos_integer(), revert_level: Logger.level()]

  @doc """
  Builds the revert configuration from an environment map, raising on invalid values so a
  misconfigured release fails at boot instead of silently leaving `:debug` enabled.
  """
  @spec from_env!(%{optional(String.t()) => String.t()}) :: t()
  def from_env!(env \\ System.get_env()) do
    [
      timeout_minutes: parse_timeout!(Map.get(env, "DEBUG_LOG_LEVEL_TIMEOUT_MINUTES")),
      revert_level: parse_level!(Map.get(env, "DEBUG_LOG_LEVEL_REVERT_LEVEL"))
    ]
  end

  @doc """
  Returns the configured number of minutes before an admin-enabled `:debug` level is reverted.
  """
  @spec timeout_minutes() :: pos_integer()
  def timeout_minutes, do: Keyword.get(current(), :timeout_minutes, @default_timeout_minutes)

  @doc """
  Returns the configured level restored after an admin-enabled `:debug` level times out.
  """
  @spec revert_level() :: Logger.level()
  def revert_level, do: Keyword.get(current(), :revert_level, @default_revert_level)

  defp current, do: Application.get_env(:oli, :debug_log_level_revert, [])

  defp parse_timeout!(nil), do: @default_timeout_minutes

  defp parse_timeout!(value) do
    case Integer.parse(String.trim(value)) do
      {minutes, ""} when minutes > 0 ->
        minutes

      _ ->
        raise ArgumentError,
              "DEBUG_LOG_LEVEL_TIMEOUT_MINUTES must be a positive integer, got: #{inspect(value)}"
    end
  end

  defp parse_level!(nil), do: @default_revert_level

  defp parse_level!(value) do
    normalized = value |> String.trim() |> String.downcase()

    case Enum.find(Logger.levels(), &(Atom.to_string(&1) == normalized)) do
      nil ->
        raise ArgumentError,
              "DEBUG_LOG_LEVEL_REVERT_LEVEL must be one of #{inspect(Logger.levels())}, got: #{inspect(value)}"

      :debug ->
        raise ArgumentError, "DEBUG_LOG_LEVEL_REVERT_LEVEL cannot be debug"

      level ->
        level
    end
  end
end
