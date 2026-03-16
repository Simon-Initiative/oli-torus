defmodule Oli.InstructorDashboard.DataSnapshot.Projections do
  @moduledoc """
  Capability-to-projection module registry for instructor dashboard snapshots.
  """

  alias Oli.InstructorDashboard.DataSnapshot.Projections.AiContext
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Assessments
  alias Oli.InstructorDashboard.DataSnapshot.Projections.ChallengingObjectives
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Progress
  alias Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Summary

  @type capability_key ::
          :summary
          | :progress
          | :student_support
          | :challenging_objectives
          | :assessments
          | :ai_context

  @modules %{
    summary: Summary,
    progress: Progress,
    student_support: StudentSupport,
    challenging_objectives: ChallengingObjectives,
    assessments: Assessments,
    ai_context: AiContext
  }

  @dependencies Enum.into(@modules, %{}, fn {capability_key, module} ->
                  {capability_key,
                   %{
                     required: module.required_oracles(),
                     optional: module.optional_oracles()
                   }}
                end)

  @affected_by_oracle Enum.reduce(@dependencies, %{}, fn {capability_key, deps}, acc ->
                        Enum.reduce(deps.required ++ deps.optional, acc, fn oracle_key, inner_acc ->
                          Map.update(inner_acc, oracle_key, [capability_key], &[capability_key | &1])
                        end)
                      end)
                      |> Enum.into(%{}, fn {oracle_key, capabilities} ->
                        {oracle_key, Enum.reverse(capabilities)}
                      end)

  @spec modules() :: %{required(capability_key()) => module()}
  def modules do
    @modules
  end

  @doc """
  Returns the declared oracle dependencies for each dashboard capability.

  Projection modules remain the single source of truth for required and optional
  oracle inputs so callers do not need to duplicate dependency lists elsewhere.
  """
  @spec dependencies() :: %{
          required(capability_key()) => %{required: [atom()], optional: [atom()]}
        }
  def dependencies, do: @dependencies

  @doc """
  Returns the capabilities whose derived projections can change when the given
  oracle result changes.

  This inverse lookup is derived from `dependencies/0` to support incremental
  projection recomputation without maintaining a second dependency registry.
  """
  @spec affected_capabilities(atom()) :: [capability_key()]
  def affected_capabilities(oracle_key) when is_atom(oracle_key) do
    @affected_by_oracle
    |> Map.get(oracle_key, [])
  end

  def affected_capabilities(_oracle_key), do: []
end
