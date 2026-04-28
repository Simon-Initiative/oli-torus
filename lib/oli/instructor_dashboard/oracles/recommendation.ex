defmodule Oli.InstructorDashboard.Oracles.Recommendation do
  @moduledoc """
  Oracle wrapper for instructor-dashboard recommendation lifecycle reads.
  """

  use Oli.Dashboard.Oracle

  alias Oli.Dashboard.OracleContext
  alias Oli.Delivery.Sections
  alias Oli.InstructorDashboard.Recommendations

  @impl true
  def key, do: :oracle_instructor_recommendation

  @impl true
  def version, do: 1

  @impl true
  def load(%OracleContext{} = context, opts) do
    case Sections.get_instructor_recommendation_settings(context.dashboard_context_id) do
      %{instructor_recommendations_enabled: false} ->
        {:ok, nil}

      %{instructor_recommendation_prompt_template: prompt_template} ->
        Recommendations.get_recommendation(
          context,
          Keyword.put(opts, :prompt_template, prompt_template)
        )

      _ ->
        Recommendations.get_recommendation(context, opts)
    end
  end
end
