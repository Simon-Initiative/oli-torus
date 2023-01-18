defmodule Oli.Publishing.Publications.DiffAgent do
  use Agent

  require Logger

  alias Oli.Publishing.Publications.{PublicationDiff, PublicationDiffKey}

  @doc """
  Starts the Agent.
  """
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Gets a cached publication diff by `key`.
  """
  def get(%PublicationDiffKey{key: key}) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end

  @doc """
  Puts the `value` for the given `key` in the cache`.
  """
  def put(%PublicationDiffKey{key: key}, %PublicationDiff{} = diff) do
    Agent.update(__MODULE__, &Map.put(&1, key, diff))
  end

  @doc """
  Deletes diff with `key` from the cache.

  Returns the current value of `key`, if `key` exists.
  """
  def delete(%PublicationDiffKey{key: key}) do
    Agent.get_and_update(__MODULE__, &Map.pop(&1, key))
  end

  @doc """
  Removes all publication diffs older than 10 days
  """
  def cleanup_diff_store() do
    Logger.info("Cleaning up publication diffs older than 10 days...")

    ten_days_ago = Timex.now() |> Timex.subtract(Timex.Duration.from_days(10))

    Agent.update(__MODULE__, fn cache ->
      Enum.reduce(cache, %{}, fn {k, %PublicationDiff{created_at: created_at} = v}, acc ->
        if Timex.compare(created_at, ten_days_ago) > 0 do
          # diff has not expired, keep in the cache
          Map.put(acc, k, v)
        else
          acc
        end
      end)
    end)

    Logger.info("Publication diff cleanup complete.")
  end
end
