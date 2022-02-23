defmodule Oli.Interop.CustomActivities.Score do
  import XmlBuilder

  def setup(%{
        activity_attempt: activity_attempt
      }) do

    element(
      :score,
      %{
      score_id: "percent",
      value: activity_attempt.score
      }
    )
  end

end
