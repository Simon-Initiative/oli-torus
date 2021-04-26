defmodule Oli.Repo do
  use Ecto.Repo,
    otp_app: :oli,
    adapter: Ecto.Adapters.Postgres

  @impl true
  def prepare_query(:update_all, query, opts) do
    # queries that are "update_all" operations cannot be explained with this current impl
    {query, opts}
  end

  @impl true
  def prepare_query(_operation, query, opts) do
    # Attempt to guarantee that we do not ever enable problematic query detection in production
    if Application.fetch_env!(:oli, :env) != :prod and
         Application.fetch_env!(:oli, :problematic_query_detection) == :enabled do
      threshold = Application.fetch_env!(:oli, :problematic_query_cost_threshold)
      Oli.Utils.Database.flag_problem_queries(query, threshold)
    end

    {query, opts}
  end
end
