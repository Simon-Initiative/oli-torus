defmodule Oli.Interop.CustomActivities.ActivityAttempt do
  import XmlBuilder

  alias Oli.Interop.CustomActivities.{Score}

  def setup(%{
        activity_attempt: activity_attempt
      }) do

    attributes = fetchAttributes(activity_attempt)
    children = fetchChildren(activity_attempt)
    element(
      :activity_attempt,
      attributes,
      children
    )
  end

  #  activityAttempt.dateAccessed = $(this).attr('date_accessed');
  #  activityAttempt.dateStarted = $(this).attr('date_started');
  #  activityAttempt.dateModified = $(this).attr('date_modified');
  #  activityAttempt.dateCompleted = $(this).attr('date_completed');
  #  activityAttempt.dateScored = $(this).attr('date_scored');
  #  activityAttempt.dateSubmitted = $(this).attr('date_submitted');
  #  activityAttempt.number = $(this).attr('number');
  defp fetchAttributes(activity_attempt) do
    attributes = %{
      date_accessed: DateTime.to_unix(activity_attempt.updated_at),
      date_modified: DateTime.to_unix(activity_attempt.updated_at),
      date_started: DateTime.to_unix(activity_attempt.inserted_at),
      number: activity_attempt.attempt_number
    }

    case activity_attempt.date_evaluated do
      nil ->
        attributes

      _ ->
        Map.merge(
          attributes,
          %{
            date_completed: DateTime.to_unix(activity_attempt.date_evaluated)
          }
        )
    end
  end

  defp fetchChildren(activity_attempt) do

    case activity_attempt.score do
      nil ->
        []
      _ ->
        [Score.setup(
          %{
            activity_attempt: activity_attempt
          }
                     )]
    end
  end
end
