defmodule Oli.InstructorDashboard.SummaryRecommendationAdapter.Noop do
  @moduledoc """
  Default summary recommendation adapter until the concrete `MER-5305`
  integration is available in runtime.
  """

  @behaviour Oli.InstructorDashboard.SummaryRecommendationAdapter

  @impl true
  def request_regenerate(_context, _recommendation_id), do: {:error, :not_implemented}

  @impl true
  def submit_sentiment(_context, _recommendation_id, _sentiment), do: {:error, :not_implemented}
end
