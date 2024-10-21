defmodule Oli.Delivery.Evaluation.ExplanationContext do
  alias Oli.Activities.Model.Part
  alias Oli.Delivery.Attempts.Core.PartAttempt
  alias Oli.Delivery.Attempts.Core.ActivityAttempt
  alias Oli.Resources.Revision
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Settings.Combined

  @enforce_keys [
    :part,
    :part_attempt,
    :activity_attempt,
    :resource_attempt,
    :resource_revision,
    :effective_settings
  ]

  defstruct [
    :part,
    :part_attempt,
    :activity_attempt,
    :resource_attempt,
    :resource_revision,
    :effective_settings
  ]

  @type t() :: %__MODULE__{
          part: %Part{},
          part_attempt: %PartAttempt{},
          activity_attempt: %ActivityAttempt{},
          resource_attempt: %ResourceAttempt{},
          resource_revision: %Revision{},
          effective_settings: %Combined{}
        }
end
