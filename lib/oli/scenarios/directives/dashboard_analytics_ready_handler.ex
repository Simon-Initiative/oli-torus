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
  alias Oli.Delivery.Sections

  def handle(%DashboardAnalyticsReadyDirective{} = directive, %ExecutionState{} = state) do
    with {:ok, section} <- fetch_section(state, directive.section),
         :ok <- rebuild_contained_pages(section),
         :ok <- rebuild_contained_objectives(section),
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

  defp rebuild_contained_pages(%{id: id, slug: slug} = section)
       when is_integer(id) and is_binary(slug) do
    Sections.rebuild_contained_pages(section)
    :ok
  rescue
    error -> {:error, "could not rebuild contained pages: #{Exception.message(error)}"}
  end

  defp rebuild_contained_pages(_section), do: :ok

  defp rebuild_contained_objectives(%{id: id, slug: slug} = section)
       when is_integer(id) and is_binary(slug) do
    case Sections.rebuild_contained_objectives(section) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, "could not rebuild contained objectives: #{inspect(reason)}"}
    end
  end

  defp rebuild_contained_objectives(_section), do: :ok

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
