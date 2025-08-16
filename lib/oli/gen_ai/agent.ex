defmodule Oli.GenAI.Agent do
  @moduledoc """
  Public API for starting/controlling agent runs and querying status.
  """

  alias Oli.GenAI.Agent.{RunSupervisor, Server, PubSub}

  @type run_id :: String.t()

  @spec start_run(map) :: {:ok, pid} | {:error, term}
  def start_run(%{} = args), do: RunSupervisor.start_run(args)

  @spec pause(run_id) :: :ok | {:error, term}
  def pause(run_id), do: call_server(run_id, :pause)

  @spec resume(run_id) :: :ok | {:error, term}
  def resume(run_id), do: call_server(run_id, :resume)

  @spec cancel(run_id) :: :ok | {:error, term}
  def cancel(run_id), do: call_server(run_id, :cancel)

  @spec status(run_id) :: {:ok, map} | {:error, term}
  def status(run_id), do: call_server(run_id, :status)

  @spec info(run_id) :: {:ok, map} | {:error, term}
  def info(run_id), do: call_server(run_id, :info)

  @spec subscribe(run_id) :: :ok
  def subscribe(run_id) do
    topic = PubSub.topic(run_id)
    Phoenix.PubSub.subscribe(Oli.PubSub, topic)
  end

  defp call_server(run_id, msg) do
    case Server.whereis(run_id) do
      nil ->
        {:error, "Agent run not found: #{run_id}"}

      pid ->
        try do
          GenServer.call(pid, msg, 10_000)
        catch
          :exit, {:noproc, _} ->
            {:error, "Agent run not found: #{run_id}"}

          :exit, {:timeout, _} ->
            {:error, "Agent run timed out: #{run_id}"}
        end
    end
  end
end