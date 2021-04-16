defmodule Oli.Delivery.Attempts.FeedbackActionResult do
  @derive Jason.Encoder
  defstruct [:type, :score, :out_of, :feedback, :error, :attempt_guid]
end
