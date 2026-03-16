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

  @spec modules() :: %{required(capability_key()) => module()}
  def modules do
    %{
      summary: Summary,
      progress: Progress,
      student_support: StudentSupport,
      challenging_objectives: ChallengingObjectives,
      assessments: Assessments,
      ai_context: AiContext
    }
  end

  @doc """
  Returns the declared oracle dependencies for each dashboard capability.

  Projection modules remain the single source of truth for required and optional
  oracle inputs so callers do not need to duplicate dependency lists elsewhere.
  """
  @spec dependencies() :: %{
          required(capability_key()) => %{required: [atom()], optional: [atom()]}
        }
  def dependencies do
    Enum.into(modules(), %{}, fn {capability_key, module} ->
      _ = Code.ensure_loaded(module)

      required =
        if function_exported?(module, :required_oracles, 0),
          do: module.required_oracles(),
          else: []

      optional =
        if function_exported?(module, :optional_oracles, 0),
          do: module.optional_oracles(),
          else: []

      {capability_key, %{required: required, optional: optional}}
    end)
  end

  @doc """
  Returns the capabilities whose derived projections can change when the given
  oracle result changes.

  This inverse lookup is derived from `dependencies/0` to support incremental
  projection recomputation without maintaining a second dependency registry.
  """
  @spec affected_capabilities(atom()) :: [capability_key()]
  def affected_capabilities(oracle_key) when is_atom(oracle_key) do
    # Keep projection modules as the single source of truth for oracle dependencies.
    # The tab runtime derives this inverse lookup to recalculate only the projections
    # that can change when an oracle result arrives.
    dependencies()
    |> Enum.reduce([], fn {capability_key, %{required: required, optional: optional}}, acc ->
      if oracle_key in required or oracle_key in optional do
        [capability_key | acc]
      else
        acc
      end
    end)
    |> Enum.reverse()
  end

  def affected_capabilities(_oracle_key), do: []
end
