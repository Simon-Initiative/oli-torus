defmodule Oli.Delivery.Evaluation.EvaluationContext do
  alias Oli.Resources.Revision

  @enforce_keys [
    :resource_attempt_number,
    :activity_attempt_number,
    :part_attempt_number,
    :part_attempt_guid,
    :input,
    :resource_revision,
    :activity_revision
  ]

  defstruct [
    :resource_attempt_number,
    :activity_attempt_number,
    :part_attempt_number,
    :part_attempt_guid,
    :input,
    :resource_revision,
    :activity_revision
  ]

  @type t() :: %__MODULE__{
          resource_attempt_number: integer,
          activity_attempt_number: integer,
          part_attempt_number: integer,
          part_attempt_guid: String.t(),
          input: String.t(),
          resource_revision: Revision.t(),
          activity_revision: Revision.t()
        }
end
