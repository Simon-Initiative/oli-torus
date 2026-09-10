defmodule Oli.Experiments.AssignmentIdentity do
  @moduledoc false

  alias Oli.Experiments.{ExperimentError, Scope}
  alias Oli.Experiments.Schemas.{ExperimentDefinition, Intervention}

  @doc false
  def validate_scope(%ExperimentDefinition{
        algorithm: :thompson_sampling,
        assignment_scope: scope
      })
      when scope != :intervention,
      do: invalid_scope(:thompson_sampling, scope)

  def validate_scope(%ExperimentDefinition{assignment_scope: scope})
      when scope in [:intervention, :section_enrollment],
      do: :ok

  def validate_scope(%ExperimentDefinition{algorithm: algorithm, assignment_scope: scope}),
    do: invalid_scope(algorithm, scope)

  @doc false
  def derive(%ExperimentDefinition{} = experiment, intervention, %Scope{} = scope) do
    with :ok <- validate_scope(experiment) do
      derive_validated(experiment, intervention, scope)
    end
  end

  defp derive_validated(experiment, %Intervention{id: intervention_id}, scope)
       when experiment.assignment_scope == :intervention do
    {:ok,
     %{
       scope: :intervention,
       experiment_id: experiment.id,
       intervention_id: intervention_id,
       section_id: scope.section_id,
       enrollment_id: scope.enrollment_id,
       map_key: {:intervention, experiment.id, intervention_id, scope.enrollment_id},
       assignment_key: "#{experiment.id}:#{intervention_id}:#{scope.enrollment_id}"
     }}
  end

  defp derive_validated(experiment, _intervention, scope)
       when experiment.assignment_scope == :section_enrollment do
    {:ok,
     %{
       scope: :section_enrollment,
       experiment_id: experiment.id,
       intervention_id: nil,
       section_id: scope.section_id,
       enrollment_id: scope.enrollment_id,
       map_key: {:section_enrollment, experiment.id, scope.section_id, scope.enrollment_id},
       assignment_key:
         "v2:section_enrollment:#{experiment.id}:#{scope.section_id}:#{scope.enrollment_id}"
     }}
  end

  defp derive_validated(%ExperimentDefinition{assignment_scope: :intervention}, nil, _scope) do
    {:error,
     %ExperimentError{
       type: :invalid_condition,
       message: "intervention-scoped assignment requires an intervention",
       details: %{}
     }}
  end

  defp invalid_scope(algorithm, scope) do
    {:error,
     %ExperimentError{
       type: :invalid_condition,
       message: invalid_scope_message(algorithm, scope),
       details: %{algorithm: algorithm, assignment_scope: scope}
     }}
  end

  defp invalid_scope_message(:thompson_sampling, _scope),
    do: "Thompson Sampling requires intervention assignment scope"

  defp invalid_scope_message(_algorithm, _scope),
    do: "experiment has an invalid assignment scope"
end
