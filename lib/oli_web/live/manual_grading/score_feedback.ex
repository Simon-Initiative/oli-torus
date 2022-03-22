defmodule OliWeb.ManualGrading.ScoreFeedback do

  alias OliWeb.ManualGrading.ScoreFeedback

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
