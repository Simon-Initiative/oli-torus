defmodule Oli.Delivery.Evaluation.EvaluationContext do
  @enforce_keys [
    :resource_attempt_number,
    :activity_attempt_number,
    :activity_attempt_guid,
    :part_attempt_number,
    :part_attempt_guid,
    :page_id,
    :input
  ]

  defstruct [
    :resource_attempt_number,
    :activity_attempt_number,
    :activity_attempt_guid,
    :part_attempt_number,
    :part_attempt_guid,
    :page_id,
    :input
  ]

  @type t() :: %__MODULE__{
          resource_attempt_number: integer,
          activity_attempt_number: integer,
          activity_attempt_guid: String.t(),
          part_attempt_number: integer,
          part_attempt_guid: String.t(),
          page_id: integer,
          input: String.t()
        }
end
