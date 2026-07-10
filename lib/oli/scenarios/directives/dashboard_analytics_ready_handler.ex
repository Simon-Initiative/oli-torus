defmodule Oli.Scenarios.Directives.DashboardAnalyticsReadyHandler do
  @moduledoc """
  Handles dashboard_analytics_ready directives by deterministically preparing
  analytics-backed dashboard data.

  The directive rebuilds derived section relationships used by dashboard
  projections, such as contained pages and contained objectives, then drains
  pending snapshot analytics work.

  Use this directive after learner actions that change analytics, such as
  answer_question or finalize_attempt, and before instructor dashboard
  assertions that read analytics-backed data.
  """

  alias Oli.Scenarios.DirectiveTypes.{DashboardAnalyticsReadyDirective, ExecutionState}
  alias Oli.Scenarios.Engine
  alias Oli.Delivery.Sections

  @spec handle(%DashboardAnalyticsReadyDirective{}, %ExecutionState{}) ::
          {:ok, %ExecutionState{}} | {:error, String.t()}
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
    Sections
    |> apply(:rebuild_contained_pages, [section])
    |> contained_pages_result()
  rescue
    error -> {:error, "could not rebuild contained pages: #{Exception.message(error)}"}
  end

  defp rebuild_contained_pages(_section), do: :ok

  defp contained_pages_result({:ok, _}), do: :ok
  defp contained_pages_result(:ok), do: :ok

  defp contained_pages_result({:error, reason}),
    do: {:error, "could not rebuild contained pages: #{inspect(reason)}"}

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
        :snapshots
        |> drain_queue()
        |> drain_result()

      {_, _} ->
        :ok
    end
  rescue
    error ->
      {:error, Exception.message(error)}
  end

  defp drain_queue(queue), do: Oban.drain_queue(queue: queue, with_safety: false)

  defp drain_result(result) when is_map(result) do
    failed_counts =
      result
      |> Map.take([:failure, :discard, :discarded, :cancel, :cancelled])
      |> Enum.filter(fn {_key, count} -> count != 0 end)

    case failed_counts do
      [] -> :ok
      _ -> {:error, "snapshot queue drain failed: #{inspect(Map.new(failed_counts))}"}
    end
  end

  defp drain_result(_result), do: :ok
end
