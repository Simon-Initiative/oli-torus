defmodule Oli.Delivery.Evaluation.ExplanationContext do
  alias Oli.Activities.Model.Part
  alias Oli.Delivery.Attempts.Core.PartAttempt
  alias Oli.Delivery.Attempts.Core.ActivityAttempt
  alias Oli.Resources.Revision
  alias Oli.Delivery.Attempts.Core.ResourceAttempt

  @enforce_keys [
    :part,
    :part_attempt,
    :activity_attempt,
    :resource_attempt,
    :resource_revision
  ]

  defstruct [
    :part,
    :part_attempt,
    :activity_attempt,
    :resource_attempt,
    :resource_revision
  ]

  @type t() :: %__MODULE__{
          part: Part.t(),
          part_attempt: PartAttempt.t(),
          activity_attempt: ActivityAttempt.t(),
          resource_attempt: ResourceAttempt.t(),
          resource_revision: Revision.t()
        }
end
