defmodule Oli.InstructorDashboard.Oracles.Recommendation do
  @moduledoc """
  Oracle wrapper for instructor-dashboard recommendation lifecycle reads.
  """

  use Oli.Dashboard.Oracle

  alias Oli.Dashboard.OracleContext
  alias Oli.InstructorDashboard.Recommendations

  @impl true
  def key, do: :oracle_instructor_recommendation

  @impl true
  def version, do: 1

  @impl true
  def load(%OracleContext{} = context, opts) do
    Recommendations.get_recommendation(context, opts)
  end
end
