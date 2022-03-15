defmodule Oli.Delivery.Evaluation.Actions.SubmissionActionResult do
  @derive Jason.Encoder
  defstruct [:type, :attempt_guid]
end
