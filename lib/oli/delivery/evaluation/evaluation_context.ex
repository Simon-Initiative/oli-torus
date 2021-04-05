defmodule Oli.Delivery.Evaluation.EvaluationContext do
  @enforce_keys [:resource_attempt_number, :activity_attempt_number, :part_attempt_number, :input]

  defstruct [:resource_attempt_number, :activity_attempt_number, :part_attempt_number, :input]

  @type t() :: %__MODULE__{
          resource_attempt_number: integer,
          activity_attempt_number: integer,
          part_attempt_number: integer,
          input: String.t()
        }
end
