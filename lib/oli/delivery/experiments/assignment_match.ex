defmodule Oli.Delivery.Experiments.AssignmentMatch do
  @moduledoc false

  alias Oli.Experiments.Schemas.{Assignment, Condition, ExperimentDefinition, Intervention}

  @doc false
  def hydrate(match) do
    experiment = struct(ExperimentDefinition, match.experiment)
    condition = struct(Condition, match.condition)

    assignment =
      Assignment
      |> struct(match.assignment)
      |> Map.put(:experiment, experiment)
      |> Map.put(:condition, condition)

    match
    |> Map.put(:assignment, assignment)
    |> Map.put(:experiment, experiment)
    |> Map.put(:condition, condition)
    |> Map.put(:intervention, struct(Intervention, match.intervention))
  end
end
