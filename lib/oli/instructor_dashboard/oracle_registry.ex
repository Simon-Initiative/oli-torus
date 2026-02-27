defmodule Oli.InstructorDashboard.OracleRegistry do
  @moduledoc """
  Instructor-dashboard registry wrapper built on shared dashboard contracts.
  """

  alias Oli.Dashboard.OracleRegistry
  alias Oli.Dashboard.OracleRegistry.Validator
  alias Oli.InstructorDashboard.OracleBindings

  @type consumer_key :: atom()
  @type oracle_key :: atom()

  @spec registry() :: OracleRegistry.registry()
  def registry do
    %{
      dashboard_product: :instructor_dashboard,
      consumers: OracleBindings.consumer_profiles(),
      oracles: OracleBindings.oracle_modules()
    }
  end

  @spec dependencies_for(consumer_key()) ::
          {:ok, OracleRegistry.dependency_profile()} | {:error, OracleRegistry.error()}
  def dependencies_for(consumer_key),
    do: OracleRegistry.dependencies_for(registry(), consumer_key)

  @spec required_for(consumer_key()) :: {:ok, [oracle_key()]} | {:error, OracleRegistry.error()}
  def required_for(consumer_key), do: OracleRegistry.required_for(registry(), consumer_key)

  @spec optional_for(consumer_key()) :: {:ok, [oracle_key()]} | {:error, OracleRegistry.error()}
  def optional_for(consumer_key), do: OracleRegistry.optional_for(registry(), consumer_key)

  @spec oracle_module(oracle_key()) :: {:ok, module()} | {:error, OracleRegistry.error()}
  def oracle_module(oracle_key), do: OracleRegistry.oracle_module(registry(), oracle_key)

  @spec known_consumers() :: [consumer_key()]
  def known_consumers, do: OracleRegistry.known_consumers(registry())

  @spec execution_plan_for([oracle_key()]) ::
          {:ok, [[oracle_key()]]} | {:error, OracleRegistry.error()}
  def execution_plan_for(oracle_keys),
    do: OracleRegistry.execution_plan_for(registry(), oracle_keys)

  @doc """
  Bootstrap validation hook for startup/test wiring.
  """
  @spec bootstrap_validate!() :: :ok
  def bootstrap_validate!, do: Validator.validate_on_startup!(registry())
end
