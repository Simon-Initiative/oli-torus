defmodule Oli.Experiments.XAPI.ConditionAssignmentEmitter do
  @moduledoc false

  alias Oli.Analytics.XAPI.Events.Experiment.ExperimentConditionAssigned
  alias Oli.Analytics.XAPI.StatementBundle
  alias Oli.Experiments.{AssignmentDecision, Scope}
  alias Oli.Experiments.Schemas.{Assignment, ExperimentDefinition}

  def emit(
        %Assignment{} = assignment,
        %ExperimentDefinition{} = experiment,
        %AssignmentDecision{reused?: false} = decision,
        %Scope{} = scope
      ) do
    statement = ExperimentConditionAssigned.new(assignment, experiment, decision, scope)

    %StatementBundle{
      body: Oli.Analytics.Common.to_jsonlines([statement]),
      bundle_id: "experiment-condition-assigned-#{assignment.id}",
      partition_id: assignment.section_id,
      category: :experiment_condition_assigned,
      partition: :section
    }
    |> Oli.Analytics.XAPI.emit()
  end

  def emit(_assignment, _experiment, _decision, _scope), do: :ok
end
