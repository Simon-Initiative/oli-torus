defmodule OliWeb.Delivery.ActivityInsightsState do
  @moduledoc """
  Pure state projections shared by instructor activity insight tables.
  """

  def initial_state do
    %{
      activity_summary_cache: %{},
      loaded_activity_summaries: %{},
      expanded_activity_ids: MapSet.new(),
      repair_poll_scheduled: false
    }
  end

  @doc """
  Clears the per-selection detail state.

  The summary cache and repair polling flag deliberately survive a reset so a
  previously loaded summary can be reused when a row is expanded again.
  """
  def reset do
    %{
      loaded_activity_summaries: %{},
      expanded_activity_ids: MapSet.new()
    }
  end

  @doc "Projects expanded activity IDs into the row IDs the striped table marks as open."
  def expanded_rows(ids), do: ids |> Enum.map(&"row_#{&1}") |> MapSet.new()

  def loaded?(loaded_activity_summaries, activity_id),
    do: Map.has_key?(loaded_activity_summaries, activity_id)
end
