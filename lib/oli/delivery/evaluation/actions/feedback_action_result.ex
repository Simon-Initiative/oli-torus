defmodule Oli.Delivery.Evaluation.Actions.FeedbackActionResult do
  @derive Jason.Encoder
  defstruct [:type, :score, :out_of, :feedback, :error, :attempt_guid, :part_id]
end
