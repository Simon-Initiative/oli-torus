defmodule OliWeb.ManualGrading.ScoreFeedback do

  @enforce_keys [
    :score,
    :out_of,
    :feedback
  ]
  defstruct [
    :score,
    :out_of,
    :feedback
  ]

end
