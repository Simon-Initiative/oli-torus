defmodule Oli.Delivery.ActivityProvider.AttemptPrototype do
  @moduledoc """
  An attempt prototype represents a template, or a blueprint, that the system
  uses to create actual activity attempts.

  AttemptPrototype is a fundamental unit of currency between the ActivityProvider
  and client code that uses it.
  """

  alias Oli.Delivery.Attempts.Core.{
    ActivityAttempt
  }

  defstruct [
    :revision,
    :activity_id,
    :transformed_model,
    :scoreable,
    :survey_id,
    :group_id,
    :selection_id,
    :inherit_state_from_previous
  ]

  def from_attempt(%ActivityAttempt{} = attempt) do
    %Oli.Delivery.ActivityProvider.AttemptPrototype{
      revision: attempt.revision,
      activity_id: attempt.revision.resource_id,
      transformed_model: attempt.transformed_model,
      scoreable: attempt.scoreable,
      survey_id: attempt.survey_id,
      group_id: attempt.group_id,
      selection_id: attempt.selection_id,
      inherit_state_from_previous: true
    }
  end
end
