defmodule Oli.Delivery.Evaluation.Actions.SubmissionAction do
  @derive Jason.Encoder
  defstruct [:type, :attempt_guid, :part_id]
end
