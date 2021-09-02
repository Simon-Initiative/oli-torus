defmodule Oli.Interop.CustomActivities.ActivityAttempt do

  import XmlBuilder

  def setup(
        %{
          activity_attempt: activity_attempt
        }
      ) do
    element(
      :activity_attempt,
      %{
        date_accessed: DateTime.to_unix(activity_attempt.updated_at),
        date_completed:
          case activity_attempt.date_evaluated do
            nil -> nil
            _ -> DateTime.to_unix(activity_attempt.date_evaluated)
          end,
        date_modified: DateTime.to_unix(activity_attempt.updated_at),
        date_started: DateTime.to_unix(activity_attempt.inserted_at),
        number: activity_attempt.attempt_number
      }
    )
  end
end
