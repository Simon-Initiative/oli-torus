defmodule Oli.RuntimeLogOverrides.DebugLevelRevertWorker do
  @moduledoc """
  Oban worker that reverts an admin-enabled global `:debug` log level after a timeout.

  The global log level is node-local, so each job targets the node where `:debug` was
  enabled. Jobs are a no-op when that node is no longer connected (a restarted node boots with
  its configured level) or when the node is no longer at `:debug`.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"node" => node_name, "revert_level" => revert_level}}) do
    with {:ok, level} <- parse_level(revert_level),
         {:ok, target_node} <- connected_node(node_name) do
      revert_on_node(target_node, level)
    else
      {:error, :invalid_level} ->
        {:discard, "invalid revert level #{inspect(revert_level)}"}

      {:error, :node_not_connected} ->
        Logger.info("Skipping debug log level revert: node=#{node_name} is not connected")
        :ok
    end
  end

  @doc """
  Reverts the local node's global log level to `level` only when it is still `:debug`.
  """
  @spec revert_local(Logger.level()) :: :reverted | :unchanged
  def revert_local(level) do
    case Logger.level() do
      :debug ->
        # Log before reverting so the message is not filtered out by the new level.
        Logger.warning(
          "Global log level automatically reverting from debug to #{level} node=#{node()}"
        )

        Logger.configure(level: level)
        :reverted

      _ ->
        :unchanged
    end
  end

  defp revert_on_node(target_node, level) when target_node == node() do
    revert_local(level)
    :ok
  end

  defp revert_on_node(target_node, level) do
    :erpc.call(target_node, __MODULE__, :revert_local, [level])
    :ok
  rescue
    error -> {:error, error}
  end

  defp parse_level(level) when is_binary(level) do
    case Enum.find(Logger.levels(), &(Atom.to_string(&1) == level)) do
      nil -> {:error, :invalid_level}
      level -> {:ok, level}
    end
  end

  defp parse_level(_level), do: {:error, :invalid_level}

  defp connected_node(node_name) when is_binary(node_name) do
    case Enum.find([node() | Node.list()], &(Atom.to_string(&1) == node_name)) do
      nil -> {:error, :node_not_connected}
      target_node -> {:ok, target_node}
    end
  end

  defp connected_node(_node_name), do: {:error, :node_not_connected}
end
