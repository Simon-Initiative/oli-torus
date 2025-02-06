defmodule Oli.Delivery.Evaluation.Actions.FeedbackAction do
  @derive {Jason.Encoder, except: [:trigger]}
  defstruct [
    :type,
    :score,
    :out_of,
    :feedback,
    :error,
    :attempt_guid,
    :part_id,
    :show_page,
    :explanation,
    :trigger
  ]
end
