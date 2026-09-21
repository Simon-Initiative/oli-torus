defmodule OliWeb.Delivery.InstructorDashboard.LearningObjectives.RelatedActivities.Summaries do
  @moduledoc """
  Builds the detail pane's summary for one linked activity row.

  The pane has three outcomes and renders each differently, so the outcome travels with the summary
  instead of being inferred from missing fields.
  """

  @type status :: :complete | :no_observations | :unavailable

  @doc """
  Attaches the outcome to a summary the analytics helpers produced, or builds the summary that
  stands in for one they could not.
  """
  @spec from_result(map() | nil, map()) :: map()
  def from_result(nil, activity), do: without_analytics(activity)
  def from_result(summary, _activity), do: Map.put(summary, :summary_status, :complete)

  @doc "The summary for an activity whose analytics could not be built."
  @spec without_analytics(map()) :: map()
  def without_analytics(activity) do
    %{
      resource_id: activity.resource_id,
      id: activity.resource_id,
      revision: activity.revision,
      first_attempt_pct: 0.0,
      all_attempt_pct: 0.0,
      preview_rendered: nil,
      summary_status: status_without_analytics(activity)
    }
  end

  @spec status_without_analytics(map()) :: status()
  defp status_without_analytics(%{attempts: attempts}) when is_integer(attempts) and attempts > 0,
    do: :unavailable

  defp status_without_analytics(_activity), do: :no_observations
end
