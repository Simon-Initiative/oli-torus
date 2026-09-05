defmodule Oli.Analytics.XAPI.Events.Experiment.ExperimentConditionAssigned do
  @moduledoc """
  Builds the dedicated xAPI statement that records a newly persisted experiment assignment.
  """

  alias Oli.Experiments.{AssignmentDecision, AssignConditionRequest}
  alias Oli.Experiments.Schemas.Assignment
  alias Oli.Experiments.Schemas.ExperimentDefinition
  alias Oli.Experiments.Scope
  alias Oli.Experiments.XAPI.Attributions

  @verb "http://oli.cmu.edu/extensions/verbs/experiment_condition_assigned"

  @doc "Builds a condition-assignment statement from persisted assignment state."
  @spec new(Assignment.t(), ExperimentDefinition.t(), AssignmentDecision.t(), Scope.t()) :: map()
  def new(
        %Assignment{} = assignment,
        %ExperimentDefinition{} = experiment,
        %AssignmentDecision{} = decision,
        %Scope{} = scope
      ) do
    attribution =
      Attributions.assignment_attribution(decision, %AssignConditionRequest{scope: scope},
        assignment: assignment,
        experiment: experiment
      )

    %{
      "actor" => %{
        "account" => %{
          "homePage" => Oli.Analytics.XAPI.host_name(),
          "name" => to_string(assignment.user_id)
        },
        "objectType" => "Agent"
      },
      "verb" => %{
        "id" => @verb,
        "display" => %{"en-US" => "experiment condition assigned"}
      },
      "object" => %{
        "id" =>
          "#{Oli.Analytics.XAPI.host_name()}/experiments/#{experiment.uuid}/assignments/#{assignment.id}",
        "definition" => %{
          "name" => %{"en-US" => "Experiment condition assignment"},
          "type" => "http://oli.cmu.edu/extensions/types/condition_assignment"
        },
        "objectType" => "Activity"
      },
      "context" => %{
        "extensions" => %{
          "http://oli.cmu.edu/extensions/section_id" => assignment.section_id,
          "http://oli.cmu.edu/extensions/project_id" => scope.project_id,
          "http://oli.cmu.edu/extensions/publication_id" => scope.publication_id,
          "http://oli.cmu.edu/extensions/enrollment_id" => assignment.enrollment_id,
          "http://oli.cmu.edu/extensions/experiment_attributions" => [attribution]
        }
      },
      "timestamp" => DateTime.to_iso8601(assignment.assigned_at)
    }
  end
end
