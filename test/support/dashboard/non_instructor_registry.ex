defmodule Oli.Dashboard.TestSupport.NonInstructorRegistry do
  @moduledoc false

  alias Oli.Dashboard.OracleRegistry
  alias Oli.Dashboard.TestOracles.DependentA
  alias Oli.Dashboard.TestOracles.Prerequisite

  def registry do
    %{
      dashboard_product: :analytics_dashboard,
      consumers: %{
        analytics_overview: %{
          required: [:oracle_dep_a],
          optional: []
        }
      },
      oracles: %{
        oracle_dep_a: DependentA,
        oracle_prereq: Prerequisite
      }
    }
  end

  def dependencies_for(consumer_key),
    do: OracleRegistry.dependencies_for(registry(), consumer_key)

  def oracle_module(oracle_key), do: OracleRegistry.oracle_module(registry(), oracle_key)

  def execution_plan_for(oracle_keys),
    do: OracleRegistry.execution_plan_for(registry(), oracle_keys)
end
