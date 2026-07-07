defmodule Oli.Scenarios.Directives.DashboardAnalyticsReadyHandler do
  @moduledoc """
  Handles dashboard_analytics_ready directives by deterministically draining
  pending snapshot analytics work.

  Use this directive after learner actions that change analytics, such as
  answer_question or finalize_attempt, and before instructor dashboard
  assertions that read analytics-backed data.
  """

  alias Oli.Scenarios.DirectiveTypes.{DashboardAnalyticsReadyDirective, ExecutionState}
  alias Oli.Scenarios.Engine

  def handle(%DashboardAnalyticsReadyDirective{} = directive, %ExecutionState{} = state) do
    with {:ok, _section} <- fetch_section(state, directive.section),
         :ok <- drain_snapshot_queue() do
      {:ok, state}
    else
      {:error, reason} ->
        {:error, "Failed to prepare dashboard analytics: #{reason}"}
    end
  end

  defp fetch_section(_state, nil), do: {:error, "section is required"}

  defp fetch_section(state, name) do
    case Engine.get_section(state, name) do
      nil -> {:error, "Section '#{name}' not found"}
      section -> {:ok, section}
    end
  end

  defp drain_snapshot_queue do
    oban_config = Application.get_env(:oli, Oban)

    case {oban_config[:queues], oban_config[:testing]} do
      {false, _} ->
        :ok

      {_, :manual} ->
        Oban.drain_queue(queue: :snapshots, with_safety: false)
        :ok

      {_, _} ->
        :ok
    end
  rescue
    error ->
      {:error, Exception.message(error)}
  end
end
